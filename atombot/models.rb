require 'rubygems'
gem 'dm-core'
require 'dm-core'
require 'dm-aggregates'

class User
  include DataMapper::Resource
  property :id, Integer, :serial => true, :unique_index => true
  property :jid, String, :nullable => false, :length => 128, :unique_index => true
  property :active, Boolean, :nullable => false, :default => true
  property :status, String

  has n, :tracks

  def auto_post
    false
  end

  # Find or create a user and update the status
  def self.update_status(jid, status)
    u = first(:jid => jid) || create(:jid => jid)
    u.status = status
    u.save
    u
  end

  def track(query)
    params = { :query => query, :user_id => self.id }
    t = Track.first(params) || Track.create(params)
  end

  def untrack(query)
    t = Track.first(:query => query, :user_id => self.id) or return false
    t.destroy
  end

end

class Track
  include DataMapper::Resource
  property :id, Integer, :serial => true, :unique_index => true
  property :query, String, :nullable => false, :unique_index => :user_query
  property :user_id, Integer, :nullable => false, :unique_index => :user_query

  belongs_to :user
end