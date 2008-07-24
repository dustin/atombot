#!/usr/bin/env ruby

require 'rubygems'
require 'beanstalk-client'

require 'laconicabot/config'

class Match
  attr_reader :jid, :msg

  def initialize(jid, msg)
    @jid=jid
    @msg=msg
  end
end

class Matcher

  def initialize
    @beanstalk = Beanstalk::Pool.new [LaconicaBot::Config::CONF['incoming']['beanstalkd']]
    @beanstalk.watch LaconicaBot::Config::CONF['incoming']['tube']
    @beanstalk.ignore 'default'
    @beanstalk.use LaconicaBot::Config::CONF['outgoing']['tube']
  end

  def look_for_matches(stuff)
    if /dlsspy|dustin|twitterspy|zfs|xmpp|track/.match stuff[:message]
      [Match.new('dustin@sallings.org', stuff)]
    else
      []
    end
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