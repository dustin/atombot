require "test/unit"

require "atombot/multimatch"

class QueryTest < Test::Unit::TestCase

  include AtomBot

  def test_multi_match_no_input
    run_test(MultiMatch.new([])) do |mm|
      assert_equal Set.new, mm.matches(%w(some text that can't match))
    end
  end

  def test_multi_match_one_input_miss
    run_test(MultiMatch.new([['key', 1]])) do |mm|
      assert_equal Set.new, mm.matches(%w(some text that can't match))
    end
  end

  def test_multi_match_one_input_hit
    run_test(MultiMatch.new([['match', 1]])) do |mm|
      assert_equal Set.new([1]), mm.matches(%w(some text that does match))
    end
  end

  def test_multi_match_multi_hit_one_result
    run_test(MultiMatch.new([['match', 1], ['does', 1]])) do |mm|
      assert_equal Set.new([1]), mm.matches(%w(some text that does match))
    end
  end

  def test_multi_match_multi_hit_multi_results
    run_test(MultiMatch.new([['match', 1], ['does', 2]])) do |mm|
      assert_equal Set.new([1, 2]), mm.matches(%w(some text that does match))
    end
  end

  def test_multi_match_multi_hit_single_word_multi_reuslts
    run_test(MultiMatch.new([['match', 1], ['match', 2]])) do |mm|
      assert_equal Set.new([1, 2]), mm.matches(%w(some text that does match))
    end
  end

  def test_marshalling
    min = MultiMatch.new [['key', 1]]
    m = Marshal.dump(min)
    mout = Marshal.load m
    assert_equal Set.new, mout.matches(%w(some text that can't match))
  end

  private

  def run_test(t, &block)
    yield t
    yield Marshal.load(Marshal.dump(t))
  end

end
