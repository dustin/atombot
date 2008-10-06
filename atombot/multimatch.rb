require 'trie'

require 'atombot/query'
require 'atombot/cache'

module AtomBot

  class MultiMatch

    attr_reader :version

    def self.load_all
      user_negs = Hash[* User.all.map{|u| [u.id, u.user_global_filters_as_s]}.flatten]
      away_users = Set.new(User.all(:active => false).map{|u| u.id})
      AtomBot::MultiMatch.new(Track.all.reject do |t|
            away_users.include?(t.user_id)
          end.map { |t| [t.query + " " + user_negs[t.user_id], t.user_id]})
    end

    def self.all
      c = CacheInterface.new
      matcher = c.cache[AtomBot::Cache::MATCH_KEY]
      if matcher.nil?
        matcher = load_all
        c.cache[AtomBot::Cache::MATCH_KEY] = matcher
      end
      matcher
    end

    def self.recache_all
      c = CacheInterface.new
      c.cache[AtomBot::Cache::MATCH_KEY] = load_all
    end

    # Receives a list of pairs [query, something] and returns the somethings
    # for the queries on match hit
    def initialize(queries_and_targets)
      @queries = Trie.new
      @version = CacheInterface.new.new_version_num

      queries_and_targets.each do |query, target|
        q = AtomBot::Query.new query
        value = [q, target]
        q.positive.each do |word|
          ws = word.to_s
          @queries.insert ws, value
        end
      end
    end

    def matches(words)
      Set.new(words.map do |w|
        matches_for(w).map do |q, t|
          q.matches?(words) ? t : nil
        end
      end.flatten.compact)
    end

    def matches_for(w)
      @queries[w] || []
    end

    def size
      @queries.size
    end
  end

end