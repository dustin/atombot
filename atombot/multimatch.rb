require 'atombot/query'

module AtomBot

  class MultiMatch

    # Receives a list of pairs [query, something] and returns the somethings
    # for the queries on match hit
    def initialize(queries_and_targets)
      @queries = Hash.new {|h,k| h[k] = []; h[k]}

      queries_and_targets.each do |query, target|
        q = AtomBot::Query.new query
        value = [q, target]
        q.positive.each do |word|
          @queries[word.to_s] << value
        end
      end
    end

    def matches(words)
      Set.new(words.map do |w|
        @queries[w].map do |q, t|
          q.matches?(words) ? t : nil
        end
      end.flatten.compact)
    end

    def size
      @queries.size
    end
  end

end