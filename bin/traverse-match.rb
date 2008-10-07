#!/usr/bin/env ruby

require 'atombot/multimatch'

matches = AtomBot::MultiMatch.all
puts "Marshalled to #{Marshal.dump(matches).size} bytes"
structure = matches.instance_variable_get('@queries')
structure.to_a.sort.each do |topk, topv|
  puts topk.join('')
  topv.each do |q, uid|
    puts "\t#{q} -> #{uid}"
  end
end
