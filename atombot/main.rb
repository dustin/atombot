require 'htmlentities'
require 'xmpp4r/roster'

require 'atombot/config'
require 'atombot/models'
require 'atombot/commands'
require 'atombot/delivery_helper'

module AtomBot

  class Main

    include AtomBot::DeliveryHelper

    def initialize
      @beanstalk_out = Beanstalk::Pool.new [AtomBot::Config::CONF['outgoing']['beanstalkd']]
      @beanstalk_out.watch AtomBot::Config::CONF['outgoing']['tube']
      @beanstalk_out.ignore 'default'

      @beanstalk_in = Beanstalk::Pool.new [AtomBot::Config::CONF['incoming']['beanstalkd']]
      @beanstalk_in.use AtomBot::Config::CONF['incoming']['tube']

      jid = Jabber::JID.new(AtomBot::Config::CONF['incoming']['jid'])
      @client = Jabber::Client.new(jid)
      @client.connect
      @client.auth(AtomBot::Config::CONF['incoming']['pass'])
      register_callbacks
      subscribe_to_unknown

      @num_users = 0
      @num_tracks = 0

      update_status
    end

    def update_status
      nu = User.count
      nt = Track.count
      if @num_users != nu || @num_tracks != nt
        status = "Tracking #{nt} topics for #{nu} users"
        @client.send(Jabber::Presence.new(nil, status, 1))
        @num_users = nu
        @num_tracks = nt
      end
    end

    def process_outgoing(job)
      stuff = job.ybody
      puts "]]] outgoing message to #{stuff['to']}"
      deliver stuff['to'], stuff['msg']
    end

    def process_feeder_message(message)
      entry = message.first_element('entry')
      message = HTMLEntities.new.decode(entry.first_element_text('summary'))
      id = entry.first_element_text('id')

      author = entry.first_element('source').first_element('author').first_element_text('name')
      authorlink = entry.first_element('source').first_element_text('link')

      # Strip off the author's name from the message
      message.gsub!(Regexp.new("^#{author}: "), '')

      puts "[[[ msg from #{author}: #{message}"
      @beanstalk_in.yput({:author => author,
        :authorlink => authorlink,
        :message => message,
        :id => id,
        :atom => entry.to_s
        })
    rescue StandardError, Interrupt
      puts "Error processing feeder message:  #{$!}" + $!.backtrace.join("\n\t")
    end

    def subscribe_to_unknown
      User.all(:status => nil).each {|u| subscribe_to u.jid}
      $stdout.flush
    end

    def subscribe_to(jid)
      puts "Sending subscription request to #{jid}"
      req = Jabber::Presence.new.set_type(:subscribe)
      req.to = jid
      @client.send req
    end

    def process_user_message(msg)
      return if msg.body.nil?
      decoded = HTMLEntities.new.decode(msg.body).gsub(/&/, '&amp;')
      puts "<<< User message from #{msg.from.to_s}:  #{decoded}"
      cmd, args = decoded.split(' ', 2)
      cp = AtomBot::Commands::CommandProcessor.new @client
      user = User.first(:jid => msg.from.bare.to_s) || User.create(:jid => msg.from.bare.to_s)
      cp.dispatch cmd.downcase, user, args
      update_status
    rescue StandardError, Interrupt
      puts "Error processing user message:  #{$!}" + $!.backtrace.join("\n\t")
      deliver msg.from, "Error processing your message."
    end

    def from_a_feeder?(message)
      AtomBot::Config::FEEDERS.include? message.from.bare.to_s
    end

    def register_callbacks

      @client.on_exception do |e, stream, symbol|
        puts "Exception in #{symbol}: #{e}" + e.backtrace.join("\n\t")
        $stdout.flush
      end

      @roster = Jabber::Roster::Helper.new(@client)

      @roster.add_subscription_request_callback do |roster_item, presence|
        @roster.accept_subscription(presence.from)
        subscribe_to presence.from.bare.to_s
      end

      @client.add_message_callback do |message|
        begin
          if from_a_feeder? message
            process_feeder_message message
          else
            process_user_message message
          end
          $stdout.flush
        rescue StandardError, Interrupt
          puts "Error processing incoming message:  #{$!}" + $!.backtrace.join("\n\t")
          $stdout.flush
        end
      end

      @client.add_presence_callback do |presence|
        if presence.type.nil?
          status = presence.show.nil? ? :available : presence.show
        else
          status = presence.type
        end
        puts "*** #{presence.from} -> #{status}"
        $stdout.flush
        User.update_status presence.from.bare.to_s, status.to_s
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
      puts "Got exception:  #{$!.inspect}\n" + $!.backtrace.join("\n\t")
      $stdout.flush
      sleep 5
    end

    def run
      loop { inner_loop }
    end
  end

end
