#!/usr/bin/env ruby

require 'atombot/matcher_core'

raise "Usage: #{$0} source author message..." unless $*.length > 2

source, author, msg = $*.join(' ').split(' ', 3)

matcher = AtomBot::Matcher.new

matcher.load_matches
matches = matcher.look_for_matches(
  'source' => source, 'author' => author, 'message' => msg)

puts matches
