#!/usr/bin/env ruby

require 'rubygems'
require 'beanstalk-client'

require 'atombot/config'
require 'atombot/models'
require 'atombot/query'

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

    load_matches
  end

  def load_matches
    @matches = Hash.new {|h,k| h[k] = []; h[k]}

    users = Hash[* User.all.map{|u| [u.id, u.jid]}.flatten]

    Track.all.each do |t|
      q = AtomBot::Query.new t.query
      value = [users[t.user_id], q]
      q.positive.each do |word|
        @matches[word.to_s] << value
      end
    end

    puts "Loaded #{@matches.size} things into the hash."
  end

  def look_for_matches(stuff)
    # Need some signaling to make this not happen most of the time.
    load_matches
    words = stuff[:message].downcase.split /\W+/
    words << "from:#{stuff[:author].downcase}"

    words.map {|w| @matches[w]}.map do |junk, rest|
      jid, q = junk
      unless q.nil?
        q.matches?(words) ? jid : nil
      end
    end.flatten.compact.uniq.map{|jid| Match.new(jid, stuff)}
  end

  def enqueue_match(match)
    message = "#{match.msg[:author]}: #{match.msg[:message]}"
    puts "Match sending to #{match.jid}: #{message}"
    $stdout.flush
    @beanstalk.yput({'to' => match.jid, 'msg' => message })
  end

  def process
    job = @beanstalk.reserve
    stuff = job.ybody
    puts "Processing #{stuff[:message]}"
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
