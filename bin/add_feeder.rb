#!/usr/bin/env ruby

require 'net/http'
require 'webrick'

require 'atombot/config'
require 'atombot/models'

jid, name, url_s = $*

url = URI.parse url_s

raise "Usage:  #{$0} shortname baseurl" if url.host.nil?

s = Service.new :name => name, :hostname => url.host,
  :api_path => url.path + "api",
  :jid => jid,
  :user_pattern => %Q{<a href="#{url.to_s}#\{user\}">#\{linktext\}</a>},
  :tag_pattern => %Q{<a href="#{url.to_s}tag/#\{tag\}">#\{linktext\}</a>},
  :listed => false, :api_key => WEBrick::Utils.random_string(12)

s.save
