require 'rubygems'
require 'yaml'

module LaconicaBot
  module Config
    CONF = ::YAML.load_file 'laconicabot.yml'
    FEEDERS = CONF['feeders']
    VERSION = `git rev-parse --short HEAD`
  end
end
