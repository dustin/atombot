#!/usr/bin/env ruby

require 'atombot/multimatch'

matches = AtomBot::MultiMatch.all
puts "Marshalled to #{Marshal.dump(matches).size} bytes"
structure = matches.instance_variable_get('@queries')
prev=[]
structure.each do |topk, topv|
  puts "#{topk.join('')}" unless prev == topk
  prev = topk
  puts "\t#{topv[0].to_q}\t#{topv[1]}"
end
