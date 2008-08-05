#!/usr/bin/env ruby

require 'date'

require 'rubygems'
require 'sinatra'

require 'atombot/config'
require 'atombot/models'

def atom_date(d=DateTime.now)
  d.strftime "%Y-%m-%dT%H:%M:%SZ"
end

get '/ispy/atom/:id' do
  out = <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">

 <title>IdentiSPY Feed</title>
 <subtitle>What You've Been Tracking</subtitle>
 <link href="http://bleu.west.spy.net/ispy/atom/#{params[:id]}" rel="self"/>
 <link href="http://bleu.west.spy.net/ispy/"/>
 <updated>#{atom_date}</updated>
 <author>
   <name>Dustin Sallings</name>
   <email>dustin@spy.net</email>
 </author>
 <id>http://bleu.west.spy.net/ispy/atom/#{params[:id]}</id>
EOF
  u = User.first(:id => params[:id].to_i)
  u.messages(:order => [:created_at.desc], :limit => 20).each do |m|
    out << m.atom
  end
  out << "</feed>"
  out
end
