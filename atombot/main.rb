require 'htmlentities'

require 'atombot/config'
require 'atombot/models'

module AtomBot

  class Main

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

      @client.send(Jabber::Presence.new(nil, 'Waiting...'))
    end

    def deliver(jid, message, type=:chat)
      if message.kind_of?(Jabber::Message)
        msg = message
        msg.to = jid
      else
        msg = Jabber::Message.new(jid)
        msg.type = type
        msg.body = message
      end
      @client.send msg
    end

    def process_outgoing(job)
      stuff = job.ybody
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

      puts "msg from #{author}: #{message}"
      @beanstalk_in.yput({:author => author,
        :authorlink => authorlink,
        :message => message,
        :id => id,
        :atom => entry.to_s
        })
    rescue StandardError, Interrupt
      puts "Error processing feeder message:  #{$!}" + $!.backtrace.join("\n\t")
      $stdout.flush
    end

    def process_user_message(msg)
      return if msg.body.nil?
      puts "user message from #{msg.from.to_s}: #{msg.body}"
      deliver msg.from, "Sorry, I don't currently have any control messages."
    rescue StandardError, Interrupt
      puts "Error processing user message:  #{$!}" + $!.backtrace.join("\n\t")
      $stdout.flush
    end

    def from_a_feeder?(message)
      AtomBot::Config::FEEDERS.include? message.from.bare.to_s
    end

    def register_callbacks
      @client.add_message_callback do |message|
        begin
          if from_a_feeder? message
            process_feeder_message message
          else
            process_user_message message
          end
        rescue StandardError, Interrupt
          puts "Error processing incoming message:  #{$!}" + $!.backtrace.join("\n\t")
          $stdout.flush
        end
      end

      @client.add_presence_callback do |presence|
        puts "*** #{presence.from} -> #{presence.type.nil? ? :available : presence.type}"
      end

    end

    def inner_loop      
      loop do
        job = @beanstalk_out.reserve
        process_outgoing job
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