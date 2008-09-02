#!/usr/bin/env ruby

require 'atombot/config'
require 'atombot/models'

$logger.info "Migrating..."
DataMapper.auto_migrate!