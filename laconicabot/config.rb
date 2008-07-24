require 'rubygems'
require 'yaml'

module LaconicaBot
  module Config
    CONF = ::YAML.load_file 'laconicabot.yml'
    VERSION = `git rev-parse --short HEAD`
  end
end
