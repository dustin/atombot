#!/usr/bin/env ruby

require 'rubygems'
require 'beanstalk-client'
require 'twitter'
require 'base64'

require 'atombot/config'
require 'atombot/models'
require 'atombot/query'

class ServiceHandler

  def initialize
    @beanstalk = Beanstalk::Pool.new [AtomBot::Config::CONF['services']['beanstalkd']]
    @beanstalk.watch AtomBot::Config::CONF['services']['tube']
    @beanstalk.ignore 'default'
    @beanstalk.use AtomBot::Config::CONF['outgoing']['tube']

    load_services
  end

  def load_services
    @services = Hash[* Service.all.map{|s| [s.name, s]}.flatten]
    puts "Loaded #{@services.size} services."
  end

  def send_response(jid, message)
    @beanstalk.yput({'to' => jid, 'msg' => message })
  end

  def resolve_user(uid)
    User.first :id => uid
  end

  def error(user, msg)
    send_response user.jid, ":( #{msg}"
  end

  def success(user, msg)
    send_response user.jid, ":) #{msg}"
  end

  def service_for(svc, username, password)
    puts "Getting a service for #{username}: #{svc.inspect}"
    Twitter::Base.new username, password, svc.hostname, svc.api_path
  end

  def process_setup(user, stuff)
    svc = @services[stuff[:service]]
    error user, "svc not found, known services: #{@services.keys.sort.join ', '}" and return if svc.nil?
    s = service_for(svc, stuff[:username], stuff[:password])
    begin
      # identi.ca doesn't seem to support this call
      # s.verify_credentials
      us = user.user_services.first(:service_id => svc.id) || user.user_services.new(:user => user, :service => svc)
      us.login = stuff[:username]
      us.password = Base64.encode64(stuff[:password]).strip
      us.save
      success user, "Registered for #{svc.name}"
    rescue StandardError, Interrupt
      puts "#{$!}" + $!.backtrace.join("\n\t")
      error user, "Failed to register for #{svc.name} - check your password and stuff"
    end
  end

  def process
    job = @beanstalk.reserve
    stuff = job.ybody
    user = resolve_user stuff[:user]
    puts "Processing #{stuff.merge(:password => 'xxxxxxxx').inspect} for #{user.jid}"
    self.send "process_#{stuff[:type]}", user, stuff
    job.delete
  rescue StandardError, Interrupt
    puts "Error in run process.  #{$!}" + $!.backtrace.join("\n\t")
    sleep 1
  ensure
    $stdout.flush
  end

  def run
    loop { process }
  end

end

ServiceHandler.new.run
