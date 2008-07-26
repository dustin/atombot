require 'rubygems'
gem 'dm-core'
require 'dm-core'
require 'yaml'

module AtomBot
  module Config
    CONF = ::YAML.load_file 'atombot.yml'
    FEEDERS = CONF['feeders']
    VERSION = `git rev-parse --short HEAD`
    SCREEN_NAME = CONF['incoming']['jid']

    DataMapper.setup(:default, CONF['general']['db'])
  end
end
