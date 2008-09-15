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
    $logger.info "Loaded #{@services.size} services."
  end

  def send_response(jid, message)
    @beanstalk.yput({'to' => jid, 'msg' => message }, 512)
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
    $logger.info "Getting a service for #{username}: #{svc.inspect}"
    Twitter::Base.new username, password, svc.hostname, svc.api_path
  end

  def with_registered_user_service(user, svcname)
    svc = @services[svcname]
    error user, "svc not found, known services: #{@services.keys.sort.join ', '}" and return if svc.nil?
    userv = user.user_services.first(:service_id => svc.id)
    if userv
      yield userv, service_for(userv.service, userv.login, Base64.decode64(userv.password))
    else
      error user, "You are not registered with #{svcname} (see help add_service)"
    end
  end

  def mk_url(usvc, resp)
    case usvc.service.name
    when 'twitter'
      "http://twitter.com/#{usvc.login}/statuses/#{resp.id}"
    when 'identica'
      "http://identi.ca/notice/#{resp.id}"
    else
      "(unhandled service:  #{usvc.service.name})"
    end
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

      if user.default_service_id.nil?
        user.default_service_id = svc.id
        user.save
      end
      success user, "Registered for #{svc.name}"
    rescue StandardError, Interrupt
      $logger.info "#{$!}" + $!.backtrace.join("\n\t")
      error user, "Failed to register for #{svc.name} - check your password and stuff"
    end
  end

  def process_post(user, stuff)
    with_registered_user_service(user, stuff[:service]) do |usvc, s|
      rv = s.post stuff[:msg][0...140], :source => 'identispy'
      url = mk_url usvc, rv
      success user, "Posted #{url}"
    end
  rescue StandardError, Interrupt
    error user, "Failed to post your message."
  end

  def process
    job = @beanstalk.reserve
    stuff = job.ybody
    user = resolve_user stuff[:user]
    $logger.info "Processing #{stuff.merge(:password => 'xxxxxxxx').inspect} for #{user.jid}"
    job.delete
    job = nil
    self.send "process_#{stuff[:type]}", user, stuff
  rescue StandardError, Interrupt
    $logger.info "Error in run process.  #{$!}" + $!.backtrace.join("\n\t")
    sleep 1
  ensure
    job.decay unless job.nil?
    $logger.info "Completed task for #{user.jid}"
    $stdout.flush
  end

  def run
    loop { process }
  end

end

ServiceHandler.new.run
