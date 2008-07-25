#!/usr/bin/env ruby

require 'rubygems'
require 'trie'
require 'beanstalk-client'

require 'atombot/config'

class Match
  attr_reader :jid, :msg

  def initialize(jid, msg)
    @jid=jid
    @msg=msg
  end
end

class Matcher

  def initialize
    @beanstalk = Beanstalk::Pool.new [AtomBot::Config::CONF['incoming']['beanstalkd']]
    @beanstalk.watch AtomBot::Config::CONF['incoming']['tube']
    @beanstalk.ignore 'default'
    @beanstalk.use AtomBot::Config::CONF['outgoing']['tube']
  end

  def look_for_matches(stuff)
    words = stuff[:message].gsub(/[.,'";]/, '').downcase.split
    tomatch=%w(dlsspy dustin twiterspy zfs xmpp track android protbuf datamapper
      github git jabber memcached sallings zfs trie)
    me = 'dustin@sallings.org'
    trie = Trie.new
    tomatch.each { |w| trie.insert(w, me) }

    words.map {|w| trie[w]}.flatten.uniq.map {|u| Match.new(u, stuff)}
  end

  def enqueue_match(match)
    message = "#{match.msg[:author]}: #{match.msg[:message]}"
    @beanstalk.yput({'to' => match.jid, 'msg' => message })
  end

  def process
    job = @beanstalk.reserve
    stuff = job.ybody
    matches = look_for_matches stuff
    job.delete
    matches.each { |match| enqueue_match match }
  rescue StandardError, Interrupt
    puts "Error in run process.  #{$!}" + $!.backtrace.join("\n\t")
    sleep 1
    $stdout.flush
  end

  def run
    loop { process }
  end

end

Matcher.new.run