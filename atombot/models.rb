require 'rubygems'
gem 'dm-core'
require 'dm-core'
require 'dm-aggregates'
require 'dm-timestamps'

require 'atombot/query'
require 'atombot/jobs'

class User
  include DataMapper::Resource
  property :id, Integer, :serial => true, :unique_index => true
  property :jid, String, :nullable => false, :length => 128, :unique_index => true
  property :active, Boolean, :nullable => false, :default => true
  property :status, String
  property :auto_post, Boolean, :default => false
  property :default_service_id, Integer, :nullable => true
  property :priority, Integer, :nullable => false, :default => 65536

  has n, :tracks
  has n, :user_global_filters
  has n, :user_services
  has n, :tracked_messages
  has n, :messages, :through => :tracked_messages
  belongs_to :default_service, :class_name => "Service", :child_key => [:default_service_id]

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
    t = case query
    when Integer
      Track.first(:id => query, :user_id => self.id)
    when String
      Track.first(:query => query, :user_id => self.id)
    end or return false
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

  def change_active_state(to)
    self.active = to
    invalidate_match_cache(5)
  end

  def invalidate_match_cache(*args)
    AtomBot::JobAccess.new.rebuild(*args)
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
  # Incoming jid -- if not null, this is used to recognize services
  property :jid, String, :nullable => true, :length => 128
  # Patterns for formatting outgoing messages
  property :user_pattern, String, :nullable => true, :length => 128
  property :tag_pattern, String, :nullable => true, :length => 128
  property :listed, Boolean, :nullable => false, :default => true
  property :api_key, String, :length => 64, :nullable => true, :unique_index => true

  def link_user(user, linktext)
    if user_pattern
      eval '%Q{' + user_pattern + '}'
    else
      linktext
    end
  end

  def link_tag(tag, linktext)
    if tag_pattern
      eval '%Q{' + tag_pattern + '}'
    else
      linktext
    end
  end

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
