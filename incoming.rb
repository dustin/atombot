#!/usr/bin/env ruby

require 'rubygems'
require 'date'
require 'xmpp4r-simple'
require 'htmlentities'
require 'beanstalk-client'

require 'atombot/config'

def process_outgoing(job, server)
  stuff = job.ybody
  server.deliver stuff['to'], stuff['msg']
end

def inner_loop(server)
  beanstalk = Beanstalk::Pool.new [AtomBot::Config::CONF['outgoing']['beanstalkd']]
  beanstalk.watch AtomBot::Config::CONF['outgoing']['tube']
  beanstalk.ignore 'default'

  loop do
    server.xmpp_updates
    begin
      # Process 100 outgoing or wait for a 15 minute delay.  Whichever
      # comes first.
      100.times do
        job = beanstalk.reserve 900
        process_outgoing job, server
        job.delete
      end
    rescue Beanstalk::TimedOut
      nil
    end
  end
rescue StandardError, Interrupt
  puts "Error in inner loop:  #{$!}" + $!.backtrace.join("\n\t")
  $stderr.flush
end

# <message xmlns="jabber:client" from="update@identi.ca/bourdindaemon" type="chat" to="laconica@west.spy.net">
#   <body>micheleconnolly: Every time I get a TweetDeck notification I think a train is about to pull out from the station.</body>
#   <html xmlns="http://jabber.org/protocol/xhtml-im">
#     <body xmlns="http://www.w3.org/1999/xhtml">
#     : Every time I get a TweetDeck notification I think a train is about to pull out from the station.
#     <a href="http://identi.ca/micheleconnolly">micheleconnolly</a></body>
#   </html>
#   <entry xmlns="http://www.w3.org/2005/Atom">
#     <source>
#       <title>micheleconnolly - Identi.ca</title>
#       <link href="http://identi.ca/micheleconnolly"/>
#       <link href="http://identi.ca/micheleconnolly/rss" rel="self" type="application/rss+xml"/>
#       <author>
#         <name>micheleconnolly</name>
#       </author>
#       <icon>http://identi.ca/avatar/2788-96-20080702205914.png</icon>
#     </source>
#     <title>micheleconnolly: Every time I get a TweetDeck notification I think a train is about to pull out from the station.</title>
#     <summary>micheleconnolly: Every time I get a TweetDeck notification I think a train is about to pull out from the station.</summary>
#     <link href="http://identi.ca/notice/144293" rel="alternate"/>
#     <id>http://identi.ca/notice/144293</id>
#     <published>2008-07-24T05:25:03+00:00</published>
#     <updated>2008-07-24T05:25:03+00:00</updated>
#   </entry>
# </message>

class MyClient < Jabber::Simple

  def initialize(jid, pass)
    @beanstalk = Beanstalk::Pool.new [AtomBot::Config::CONF['incoming']['beanstalkd']]
    @beanstalk.use AtomBot::Config::CONF['incoming']['tube']

    super(jid, pass)
    setup_callback
  end

  def reconnect
    puts "Reconnecting"
    $stdout.flush
    super
    setup_callback
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
    @beanstalk.yput({:author => author,
      :authorlink => authorlink,
      :message => message,
      :id => id
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

  def setup_callback
    client.add_message_callback do |message|
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
  end

  def xmpp_updates
    presence_updates
    received_messages
    new_subscriptions { |from, presence| puts "Subscribed by #{from}" }
    subscription_requests { |from, presence| puts "Sub req from #{from}" }
  end

end

loop do
  puts "Connecting..."
  $stdout.flush

  # Jabber::debug=true
  server = MyClient.new(
    AtomBot::Config::CONF['incoming']['jid'],
    AtomBot::Config::CONF['incoming']['pass'])
  server.status nil, 'Watching for messages...'

  puts "Set up with #{server.inspect}"
  $stdout.flush
  inner_loop server
end
