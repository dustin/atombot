require 'set'

module AtomBot

  DASH='-'[0]

  class QueryParseException < StandardError
  end

  class Query

    attr_reader :positive, :negative

    def initialize(query)
      positive, negative = words = query.split.uniq.partition { |w| w[0] != DASH }
      @positive = positive.map {|w| w.to_sym}
      @negative = negative.map {|w| w.sub(/^-/, '').to_sym}

      if @positive.empty?
        raise QueryParseException.new("You must supply at least one positive match")
      end
      unless Set.new(@positive).intersection(@negative).empty?
        raise QueryParseException.new("You can't have a positive and negative match for the same term.")
      end
    end

    def matches?(input)
      words = case input
      when String
        Set.new(input.gsub(/[.,'";\(\)]/, '').downcase.split)
      when Array
        Set.new(input)
      end
      pos_str = Set.new(@positive.map{|w| w.to_s})
      neg_str = Set.new(@negative.map{|w| w.to_s})

      pos_str.proper_subset?(words) && neg_str.intersection(words).empty?
    end

  end

end