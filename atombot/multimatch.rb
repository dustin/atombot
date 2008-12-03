require 'rubygems'
require 'trie'

require 'atombot/query'
require 'atombot/cache'
require 'atombot/models'

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
    def initialize(queries_and_targets, version=nil)
      @queries = Trie.new

      queries_and_targets.each do |query, target|
        q = AtomBot::Query.new query
        value = [q, target]
        q.positive.each do |word|
          ws = word.to_s
          @queries.insert ws, value
        end
      end

      @version = version.nil? ? CacheInterface.new.new_version_num : version
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

    def _dump(depth)
      rv=[@version]
      prev=''
      values=[]
      @queries.each_value do |v|
        q=v.first.to_q
        if q != prev && !values.empty?
          rv << "#{prev}\t#{values.map{|iv| iv.to_s}.join(' ')}"
          values=[]
        end
        values << v.last
        prev=q
      end
      rv << "#{prev}\t#{values.map{|v| v.to_s}.join(' ')}" unless values.empty?
      rv.join("\n")
    end

    def self._load(o)
      version=nil
      stuff = []
      o.split("\n").each do |line|
        q, nums_s=line.split("\t")
        if nums_s.nil?
          version=q.to_i
        else
          nums_s.split(" ").map{|s| s.to_i}.each do |num|
            stuff << [q, num]
          end
        end
      end
      self.new stuff, version
    end
  end

end
