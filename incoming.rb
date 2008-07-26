#!/usr/bin/env ruby

require 'rubygems'
require 'date'
require 'xmpp4r'
require 'htmlentities'
require 'beanstalk-client'

require 'atombot/config'
require 'atombot/main'

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

loop do
  puts "Connecting..."
  $stdout.flush

  # Jabber::debug=true

  AtomBot::Main.new.run

  puts "Set up with #{server.inspect}"
  $stdout.flush
  inner_loop client
end
