require "test/unit"

require "atombot/multimatch"

class QueryTest < Test::Unit::TestCase

  include AtomBot

  def test_multi_match_no_input
    mm = MultiMatch.new []
    assert_equal Set.new, mm.matches(%w(some text that can't match))
  end

  def test_multi_match_one_input_miss
    mm = MultiMatch.new [['key', 1]]
    assert_equal Set.new, mm.matches(%w(some text that can't match))
  end

  def test_multi_match_one_input_hit
    mm = MultiMatch.new [['match', 1]]
    assert_equal Set.new([1]), mm.matches(%w(some text that does match))
  end

  def test_multi_match_multi_hit_one_result
    mm = MultiMatch.new [['match', 1], ['does', 1]]
    assert_equal Set.new([1]), mm.matches(%w(some text that does match))
  end

  def test_multi_match_multi_hit_multi_results
    mm = MultiMatch.new [['match', 1], ['does', 2]]
    assert_equal Set.new([1, 2]), mm.matches(%w(some text that does match))
  end

  def test_multi_match_multi_hit_single_word_multi_reuslts
    mm = MultiMatch.new [['match', 1], ['match', 2]]
    assert_equal Set.new([1, 2]), mm.matches(%w(some text that does match))
  end

end