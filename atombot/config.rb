require 'rubygems'
require 'yaml'

module AtomBot
  module Config
    CONF = ::YAML.load_file 'atombot.yml'
    FEEDERS = CONF['feeders']
    VERSION = `git rev-parse --short HEAD`
  end
end
