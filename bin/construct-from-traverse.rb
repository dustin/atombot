#!/usr/bin/env ruby

require 'rubygems'
require 'trie'

t=Trie.new

k=''
$stdin.each do |l|
  a=l.strip.split("\t")
  case a.size
  when 1
    k=a.first
  when 2
    t.insert k, a
  else
    raise "WTF is #{a.inspect}"
  end
end

puts "Marshalled to #{Marshal.dump(t).size}"