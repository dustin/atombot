#!/usr/bin/env ruby

require 'atombot/config'
require 'atombot/models'

puts "Migrating..."
DataMapper.auto_migrate!