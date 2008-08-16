require 'rubygems'
gem 'dm-core'
require 'dm-core'
require 'dm-aggregates'
require 'dm-timestamps'

require 'atombot/query'
require 'atombot/cache'

class User
  include AtomBot::Cache
  include DataMapper::Resource
  property :id, Integer, :serial => true, :unique_index => true
  property :jid, String, :nullable => false, :length => 128, :unique_index => true
  property :active, Boolean, :nullable => false, :default => true
  property :status, String
  property :auto_post, Boolean, :default => false

  has n, :tracks
  has n, :user_global_filters
  has n, :user_services
  has n, :tracked_messages
  has n, :messages, :through => :tracked_messages

  # Find or create a user and update the status
  def self.update_status(jid, status)
    u = first(:jid => jid) || create(:jid => jid)
    u.status = status
    u.save
    u
  end

  def ready_to_receive_message
    self.active && ['available', 'chat', 'away'].include?(self.status)
  end

  def track(query)
    # Validate the query...
    AtomBot::Query.new query
    params = { :query => query, :user_id => self.id }
    t = Track.first(params) || Track.create(params)
    invalidate_match_cache
  end

  def untrack(query)
    t = Track.first(:query => query, :user_id => self.id) or return false
    t.destroy
    invalidate_match_cache
  end

  def stop(word)
    params = { :word => word, :user_id => self.id }
    t = UserGlobalFilter.first(params) || UserGlobalFilter.create(params)
    invalidate_match_cache
  end

  def unstop(word)
    t = UserGlobalFilter.first(:word => word, :user_id => self.id) or return false
    t.destroy
    invalidate_match_cache
  end

  def user_global_filters_as_s
    user_global_filters.map{|x| "-#{x.word}"}.join(" ")
  end

  def invalidate_match_cache
    cache.delete AtomBot::Cache::MATCH_KEY
  end
end

class Track
  include DataMapper::Resource
  property :id, Integer, :serial => true, :unique_index => true
  property :query, String, :nullable => false, :unique_index => :user_query
  property :user_id, Integer, :nullable => false, :unique_index => :user_query

  belongs_to :user
end

class UserGlobalFilter
  include DataMapper::Resource
  property :id, Integer, :serial => true, :unique_index => true
  property :user_id, Integer, :nullable => false, :unique_index => :user_query
  property :word, String, :nullable => false, :unique_index => :user_query

  belongs_to :user
end

class Service
  include DataMapper::Resource
  property :id, Integer, :serial => true, :unique_index => true
  property :name, String, :nullable => false, :unique_index => true
  property :hostname, String, :nullable => false
  property :api_path, String, :nullable => false
end

class UserService
  include DataMapper::Resource
  property :id, Integer, :serial => true, :nullable => false, :unique_index => true
  property :user_id, Integer, :nullable => false, :unique_index => :idx_us_u
  property :service_id, Integer, :nullable => false, :unique_index => :idx_us_u
  property :login, String, :nullable => false
  property :password, String, :nullable => false
  belongs_to :user
  belongs_to :service
end

class Message
  include DataMapper::Resource
  property :id, Integer, :serial => true, :nullable => false, :unique_index => true
  property :service_id, Integer, :nullable => false
  property :remote_id, Integer, :nullable => false
  property :sender_name, String, :nullable => false
  property :body, String, :length => 240
  property :atom, Text, :lazy => false
  property :created_at, DateTime, :index => true

  belongs_to :service
end

class TrackedMessage
  include DataMapper::Resource
  property :id, Integer, :serial => true, :nullable => false, :unique_index => true
  property :user_id, Integer, :nullable => false, :index => true
  property :message_id, Integer, :nullable => false, :index => true

  belongs_to :user
  belongs_to :message
end
