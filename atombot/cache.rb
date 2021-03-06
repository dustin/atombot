require 'rubygems'
require 'memcache'

require 'atombot/config'

module AtomBot
  module Cache

    CACHE_VERSION=5
    MATCH_KEY = "matches-#{CACHE_VERSION}" unless defined? MATCH_KEY

    def init_cache
      conf = AtomBot::Config::CONF['general']
      MemCache.new([conf.fetch('memcache', 'localhost:11211')],
        :compression => false,
        :namespace => conf.fetch('cache_namespace', 'atombot'))
    end

    def cache
      @cache ||= init_cache
    end

    def get_version_num(name="version-#{CACHE_VERSION}")
      cache.add(name, "0")
      cache.incr(name, 0)
    end

    def new_version_num(name="version-#{CACHE_VERSION}")
      cache.add(name, "0")
      cache.incr(name)
    end

  end

  class CacheInterface
    include Cache
  end
end
