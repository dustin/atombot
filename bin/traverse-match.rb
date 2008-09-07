#!/usr/bin/env ruby

require 'atombot/multimatch'

matches = AtomBot::MultiMatch.all
structure = matches.instance_variable_get('@queries')
structure.to_a.sort.each do |topk, topv|
  puts topk
  topv.each do |q, uid|
    puts "\t#{q} -> #{uid}"
  end
end
