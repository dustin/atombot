#!/usr/bin/env ruby

require 'rubygems'
require 'beanstalk-client'

require 'atombot/config'
require 'atombot/models'
require 'atombot/query'
require 'atombot/multimatch'

class Match
  attr_reader :uid, :msg

  def initialize(uid, msg)
    @uid=uid
    @msg=msg
  end

  def user
    User.first :id => @uid
  end
end

class Matcher

  def initialize
    @beanstalk = Beanstalk::Pool.new [AtomBot::Config::CONF['incoming']['beanstalkd']]
    @beanstalk.watch AtomBot::Config::CONF['incoming']['tube']
    @beanstalk.ignore 'default'
    @beanstalk.use AtomBot::Config::CONF['outgoing']['tube']

    load_matches
  end

  def load_matches
    @matcher = AtomBot::MultiMatch.new(Track.all.map{|t| [t.query, t.user_id]})
    puts "Loaded #{@matcher.size} matches"
  end

  def look_for_matches(stuff)
    # Need some signaling to make this not happen most of the time.
    load_matches
    words = Set.new(stuff[:message].downcase.split(/\W+/))
    words << "from:#{stuff[:author].downcase}"
    words << "#{stuff[:author].downcase}"

    @matcher.matches(words).map { |id| Match.new(id, stuff) }
  end

  def enqueue_match(match)
    message = "#{match.msg[:author]}: #{match.msg[:message]}"
    user = match.user
    puts "Match sending to #{user.jid}: #{message}"
    $stdout.flush
    @beanstalk.yput({'to' => user.jid, 'msg' => message })
  end

  def process
    job = @beanstalk.reserve
    stuff = job.ybody
    puts "Processing #{stuff[:message]}"
    matches = look_for_matches stuff
    job.delete
    job = nil
    matches.each { |match| enqueue_match match }
  rescue StandardError, Interrupt
    puts "Error in run process.  #{$!}" + $!.backtrace.join("\n\t")
    sleep 1
  ensure
    job.decay unless job.nil?
    $stdout.flush
  end

  def run
    loop { process }
  end

end

Matcher.new.run
