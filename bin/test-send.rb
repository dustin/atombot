#!/usr/bin/env ruby

require 'rubygems'
require 'beanstalk-client'

begin
  CONF = YAML.load_file 'laconicabot.yml'
rescue Errno::ENOENT
  unless ENV.has_key?('BEANSTALK_SERVER') && ENV.has_key?('BEANSTALK_TUBE')
    raise "No laconicabot.yml or BEANSTALK_SERVER and BEANSTALK_TUBE env"
  end
  CONF = { 'outgoing' => {
    'beanstalkd' => ENV['BEANSTALK_SERVER'],
    'tube' => ENV['BEANSTALK_TUBE']
    }}
end

BEANSTALK = Beanstalk::Pool.new [CONF['outgoing']['beanstalkd']]
BEANSTALK.use CONF['outgoing']['tube']

# Add the commandline into the queue.
BEANSTALK.yput({"to" => $*[0], "msg" => $*[1]})
