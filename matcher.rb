#!/usr/bin/env ruby

require 'benchmark'

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

    @services = Hash[* Service.all.map{|s| [s.name, s]}.flatten]
  end

  def load_matches
    timing = Benchmark.measure do
      @matcher = AtomBot::MultiMatch.all
    end
    printf "... Loaded #{@matcher.size} matches in %.5fs\n", timing.real
  end

  def look_for_matches(stuff)
    words = Set.new(stuff[:message].downcase.split(/\W+/))
    words << "from:#{stuff[:author].downcase}"
    words << "source:#{stuff[:source]}"
    words << "#{stuff[:author].downcase}"
    @matcher.matches(words).map { |id| Match.new(id, stuff) }
  end

  def enqueue_match(msg, match)
    message = "#{match.msg[:author]}: #{match.msg[:message]}"
    user = match.user
    puts "]]] #{user.jid}"
    $stdout.flush
    @beanstalk.yput(match.msg.merge({'to' => user.jid}))
    TrackedMessage.create(:user_id => user.id, :message_id => msg.id)
  end

  def store_message(stuff)
    Message.create(:service_id => @services[stuff[:source]].id,
      :remote_id => -1, :sender_name => stuff[:author],
      :body => stuff[:message], :atom => stuff[:atom])
  end

  def process
    job = @beanstalk.reserve
    timing = Benchmark.measure do
      stuff = job.ybody
      puts "[[[ #{stuff[:author]}: #{stuff[:message]}"
      # Need some signaling to make this not happen most of the time.
      load_matches
      matches = look_for_matches stuff
      msg = store_message(stuff)
      job.delete
      job = nil
      matches.each { |match| enqueue_match msg, match }
    end
    printf "... Total processing time was %.5fs\n", timing.real
  rescue StandardError, Interrupt
    puts "Error in run process.  #{$!}" + $!.backtrace.join("\n\t")
    sleep 1
  ensure
    job.decay unless job.nil?
    $stdout.flush
  end

  def run
    20.times { process }
    puts "!!! Did 20 laps, exiting."
  end

end

Matcher.new.run
