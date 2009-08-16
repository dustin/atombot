require 'rubygems'
require 'trie'

require 'atombot/query'
require 'atombot/cache'
require 'atombot/models'

module AtomBot

  class MultiMatch

    attr_reader :version

    def self.load_all
      # Don't have groupby here, so I'm going to fake it
      user_negs_set = Hash.new { |h,k| h[k] = Set.new }
      UserGlobalFilter.all.each {|f| user_negs_set[f.user_id] << f.word}
      user_negs = {}
      user_negs_set.each { |k,v| user_negs[k] = v.to_a.map{|n| "-#{n}"}.join(' ') }
      user_negs_set = nil

      $logger.info "Loaded #{user_negs.size} user negs."
      away_users = Set.new(User.all(:active => false).map{|u| u.id})
      $logger.info "Loaded #{away_users.size} away users."
      am = AtomBot::MultiMatch.new
      Track.all.reject { |t| away_users.include?(t.user_id) }.each do |t|
        am.add_query_and_target(t.query + " " + (user_negs[t.user_id] || ""), t.user_id)
      end
      $logger.info "Loaded #{am.size} multimatches"
      am.new_version
      am
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
    def initialize(queries_and_targets=nil, version=nil)
      @queries = Trie.new

      if queries_and_targets
        queries_and_targets.each { |query, target| add_query_and_target query, target }
        new_version
      end
    end

    def add_query_and_target(query, target)
      q = AtomBot::Query.new query
      value = [q, target]
      q.positive.each { |word| @queries.insert word.to_s, value }
    end

    def new_version
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
