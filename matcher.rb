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
    # Currently the only supported service.
    @service = Service.first(:name => 'identica')
  end

  def load_matches
    user_negs = Hash[* User.all.map{|u| [u.id, u.user_global_filters_as_s]}.flatten]
    @matcher = AtomBot::MultiMatch.new(Track.all.map{|t| [t.query + " " + user_negs[t.user_id], t.user_id]})
    puts "Loaded #{@matcher.size} matches"
  end

  def look_for_matches(stuff)
    # Need some signaling to make this not happen most of the time.
    load_matches
    words = Set.new(stuff[:message].downcase.split(/\W+/))
    words << "from:#{stuff[:author].downcase}"
    words << "source:#{stuff[:source]}"
    words << "#{stuff[:author].downcase}"
    @matcher.matches(words).map { |id| Match.new(id, stuff) }
  end

  def enqueue_match(msg, match)
    message = "#{match.msg[:author]}: #{match.msg[:message]}"
    user = match.user
    puts "Match sending to #{user.jid}: #{message}"
    $stdout.flush
    @beanstalk.yput({'to' => user.jid, 'msg' => message })
    TrackedMessage.create(:user_id => user.id, :message_id => msg.id)
  end

  def store_message(stuff)
    # XXX:  Allow for more than one service.
    # XXX:  Fix the remote IDs
    Message.create(:service_id => @service.id, :remote_id => -1,
      :sender_name => stuff[:author], :body => stuff[:message],
      :atom => stuff[:atom])
  end

  def process
    job = @beanstalk.reserve
    stuff = job.ybody
    puts "Processing #{stuff[:message]}"
    matches = look_for_matches stuff
    msg = store_message(stuff)
    job.delete
    job = nil
    matches.each { |match| enqueue_match msg, match }
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
