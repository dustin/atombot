require 'rubygems'
require 'memcache'

require 'atombot/config'

module AtomBot
  module Cache

    MATCH_KEY = "matches" unless defined? MATCH_KEY

    def init_cache
      conf = AtomBot::Config::CONF['general']
      MemCache.new([conf.fetch('memcache', 'localhost:11211')],
        :compression => false,
        :namespace => conf.fetch('cache_namespace', 'atombot'))
    end

    def cache
      @cache ||= init_cache
    end

  end

  class CacheInterface
    include Cache
  end
end