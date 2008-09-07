#!/usr/bin/env ruby

require 'atombot/config'
require 'atombot/models'
require 'beanstalk-client'
require 'date'
require 'htmlentities'
require 'rexml/document'
require 'rubygems'
require 'sinatra'

include REXML

beanstalk_in = Beanstalk::Pool.new [AtomBot::Config::CONF['incoming']['beanstalkd']]
beanstalk_in.use AtomBot::Config::CONF['incoming']['tube']

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
  u.messages(:created_at.gt => 'yesterday', :order => [:created_at.desc], :limit => 20).each do |m|
    out << m.atom
  end
  out << "</feed>"
  out
end

post '/submit/:apikey' do

  service = Service.first(:api_key => params[:apikey])
  send_data "Invalid API key\n", :status => 403 if service.nil?

  msg = Document.new(params[:msg])
  entry = msg.elements["//entry"]
  message = HTMLEntities.new.decode(entry.elements["//summary"].text)
  id = entry.elements["//id"].text
  author = entry.elements["//source/author/name"].text
  authorlink = entry.elements["//source/link"].text

  message.gsub!(Regexp.new("^#{author}: "), '')

  beanstalk_in.yput({:author => author,
    :source => service.name,
    :authorlink => authorlink,
    :message => message,
    :id => id,
    :atom => entry.to_s
    })
end