require 'rubygems'
gem 'dm-core'
require 'dm-core'
require 'yaml'

require 'atombot/logging'

module AtomBot
  module Config
    CONF = ::YAML.load_file 'atombot.yml'
    VERSION = `git describe`.strip
    SCREEN_NAME = CONF['incoming']['jid']
    IGNORED_JIDS = CONF['ignored'] || []

    DataMapper.setup(:default, CONF['general']['db'])
  end
end
