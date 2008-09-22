require 'htmlentities'
require 'xmpp4r/roster'
require 'xmpp4r/discovery'
require 'xmpp4r/dataforms'
require 'xmpp4r/command/iq/command'
require 'xmpp4r/command/helper/responder'
require 'xmpp4r/version/helper/simpleresponder'

require 'atombot/config'
require 'atombot/models'
require 'atombot/commands'
require 'atombot/msg_formatter'
require 'atombot/delivery_helper'
require 'atombot/xmpp_commands'

module AtomBot

  class Main

    include AtomBot::MsgFormatter
    include AtomBot::DeliveryHelper

    def initialize(resource, status=1)
      @beanstalk_out = Beanstalk::Pool.new [AtomBot::Config::CONF['outgoing']['beanstalkd']]
      @beanstalk_out.watch AtomBot::Config::CONF['outgoing']['tube']
      @beanstalk_out.ignore 'default'

      @beanstalk_in = Beanstalk::Pool.new [AtomBot::Config::CONF['incoming']['beanstalkd']]
      @beanstalk_in.use AtomBot::Config::CONF['incoming']['tube']

      @services = Hash[* Service.all(:jid.not => nil).map{|s| [s.jid, s]}.flatten]

      jid = Jabber::JID.new(AtomBot::Config::CONF['incoming']['jid'])
      jid.resource=resource
      @jid = jid
      @client = Jabber::Client.new(jid)
      @client.connect(AtomBot::Config::CONF['incoming']['server'],
        AtomBot::Config::CONF['incoming'].fetch('port', 5222))
      @client.auth(AtomBot::Config::CONF['incoming']['pass'])
      @status=status

      register_callbacks

      @num_users = 0
      @num_tracks = 0

      set_status "To Serve Man"
      update_status
    end

    def egress_only?
      @status < 0
    end

    def set_status(msg)
      show = egress_only? ? :xa : nil
      @client.send(Jabber::Presence.new(show, msg, @status))
    end

    def update_status
      unless egress_only?
        nu = User.count
        nt = Track.count
        if @num_users != nu || @num_tracks != nt
          set_status "Tracking #{nt} topics for #{nu} users"
          @num_users = nu
          @num_tracks = nt
        end
      end
    end

    def process_outgoing(job)
      stuff = job.ybody
      $logger.info "]]] #{stuff['to']}"
      if stuff['message']
        deliver stuff['to'], format_track_msg(stuff)
      else
        deliver stuff['to'], stuff['msg']
      end
    end

    def process_feeder_message(message)
      source = @services[message.from.bare.to_s].name
      entry = message.first_element('entry')
      message = HTMLEntities.new.decode(entry.first_element_text('summary'))
      id = entry.first_element_text('id')

      author = entry.first_element('source').first_element('author').first_element_text('name')
      authorlink = entry.first_element('source').first_element_text('link')

      # Strip off the author's name from the message
      message.gsub!(Regexp.new("^#{author}: "), '')

      $logger.info "[[[ msg from [#{source}] #{author}: #{message}"
      @beanstalk_in.yput({'author' => author,
        'source' => source,
        'authorlink' => authorlink,
        'message' => message,
        'id' => id,
        'atom' => entry.to_s
        })
    rescue StandardError, Interrupt
      $logger.info "Error processing feeder message:  #{$!}" + $!.backtrace.join("\n\t") + "\n" + message.to_s
    end

    def subscribe_to_unknown
      User.all(:status => nil).each {|u| subscribe_to u.jid}
      $stdout.flush
    end

    def subscribe_to(jid)
      $logger.info "Sending subscription request to #{jid}"
      req = Jabber::Presence.new.set_type(:subscribe)
      req.to = jid
      @client.send req
    end

    def process_user_message(msg)
      return if msg.body.nil?
      decoded = HTMLEntities.new.decode(msg.body).gsub(/&/, '&amp;')
      $logger.info "<<< User message from #{msg.from.to_s}:  #{decoded}"
      cmd, args = decoded.split(' ', 2)
      cp = AtomBot::Commands::CommandProcessor.new @client
      user = User.first(:jid => msg.from.bare.to_s) || User.create(:jid => msg.from.bare.to_s)
      cp.dispatch cmd.downcase, user, args
      update_status
    rescue StandardError, Interrupt
      $logger.info "Error processing user message:  #{$!}" + $!.backtrace.join("\n\t")
      deliver msg.from.bare.to_s, "Error processing your message (#{$!})"
    end

    def from_a_feeder?(message)
      @services.include? message.from.bare.to_s
    end

    def ignored_sender?(message)
      AtomBot::Config::IGNORED_JIDS.include? message.from.bare.to_s
    end

    def initialize_commands
      @commands = Hash[*AtomBot::XMPPCommands.commands.map{|cn| c=cn.new; [c.node, c]}.flatten]
    end

    def register_callbacks

      @client.on_exception do |e, stream, symbol|
        $logger.info "Exception in #{symbol}: #{e.inspect}"
        unless e.nil?
          $logger.info e.backtrace.join("\n\t")
        end
        $stdout.flush
      end

      @roster = Jabber::Roster::Helper.new(@client)

      @client.add_message_callback do |message|
        begin
          if message.type == :error
            $logger.info "Error message from #{message.from.to_s}:  #{message.to_s}"
          elsif ignored_sender? message
            $logger.info "Ignored message from #{message.from.to_s}"
          elsif from_a_feeder? message
            process_feeder_message message
          else
            process_user_message message
          end
          $stdout.flush
        rescue StandardError, Interrupt
          $logger.info "Error processing incoming message:  #{$!}" + $!.backtrace.join("\n\t")
          $stdout.flush
        end
      end

      Jabber::Version::SimpleResponder.new(@client,
        'IdentiSpy', AtomBot::Config::VERSION, 'Linux')

      unless egress_only?
        @roster.add_subscription_request_callback do |roster_item, presence|
          @roster.accept_subscription(presence.from)
          subscribe_to presence.from.bare.to_s
          AtomBot::Config::CONF['admins'].each do |admin|
            deliver admin, "Registered new user: #{presence.from.bare.to_s}"
          end
        end

        @client.add_presence_callback do |presence|
          status = if presence.type.nil?
            presence.show.nil? ? :available : presence.show
          else
            presence.type
          end
          $logger.info "*** #{presence.from} -> #{status}"
          $stdout.flush
          User.update_status presence.from.bare.to_s, status.to_s
        end

        @cmd_helper = Jabber::Command::Responder.new(@client)
        initialize_commands

        @cmd_helper.add_commands_disco_callback do |iq|
          i = Jabber::Iq::new(:result, iq.from)
          i.from = @jid
          i.id = iq.id
          i.query = Jabber::Discovery::IqQueryDiscoItems::new
          i.query.node='http://jabber.org/protocol/commands'
          @commands.each_pair do |node, command|
            i.query.add(Jabber::Discovery::Item::new(@jid, command.name, command.node))
          end
          @client.send(i)
        end

        @cmd_helper.add_commands_exec_callback do |iq|
          cmd_node = iq.command.attributes['node']
          @commands[cmd_node].execute(@client, iq)
        end

        subscribe_to_unknown
      end
    end

    def inner_loop      
      loop do
        job = @beanstalk_out.reserve
        process_outgoing job
        $stdout.flush
        job.delete
      end
    rescue StandardError, Interrupt
      $logger.info "Got exception:  #{$!.inspect}\n" + $!.backtrace.join("\n\t")
      $stdout.flush
      sleep 5
    end

    def run
      $logger.info "Processing..."
      $stdout.flush
      loop { inner_loop }
    end
  end

end
