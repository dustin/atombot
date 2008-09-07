#!/usr/bin/env ruby

require 'atombot/matcher_core'

source, author, msg = $*.join(' ').split(' ', 3)

matcher = AtomBot::Matcher.new

matcher.load_matches
matches = matcher.look_for_matches(
  :source => source, :author => author, :message => msg)

puts matches