require "test/unit"

require "atombot/query"

class QueryTest < Test::Unit::TestCase

  include AtomBot

  def test_single_construct
    q = Query.new 'aword'
    assert_equal [:aword], q.positive
    assert_equal [], q.negative
  end

  def test_multiple_construct
    q = Query.new 'aword anotherword'
    assert_equal [:aword, :anotherword], q.positive
    assert_equal [], q.negative
  end

  def test_duplicate_construct
    q = Query.new 'aword anotherword aword'
    assert_equal [:aword, :anotherword], q.positive
    assert_equal [], q.negative
  end

  def test_empty_construct
    assert_raise(QueryParseException) { q = Query.new '' }
  end

  def test_negative_only_construct
    assert_raise(QueryParseException) { q = Query.new '-junk' }
  end

  def test_positive_and_negative_construct
    q = Query.new 'aword anotherword -badword -otherbadword'
    assert_equal [:aword, :anotherword], q.positive
    assert_equal [:badword, :otherbadword], q.negative
  end

  def test_positive_and_negative_overlap_construct
    assert_raise(QueryParseException) { q = Query.new 'something -something' }
  end

  # Match tests

  def test_simple_postive_match
    q = Query.new 'word'
    assert q.matches?('This thing contains a word.')
  end

  def test_simple_negative_match
    q = Query.new 'word'
    assert !q.matches?('But this one does not.')
  end

  def test_multi_positive_match
    q = Query.new 'cool stuff'
    assert q.matches?("This is about some really cool stuff.")
    assert q.matches?("Cool and stuff don't need to be next to each other.")

    assert !q.matches?("This one is just cool.")
    assert !q.matches?("And this one just has stuff.")
  end

  def test_multi_positive_and_negative_matches
    q = Query.new 'cool stuff -paint -brush'
    assert q.matches?("Stuff that's cool matches.")
    assert !q.matches?("Is a paint brush cool stuff?")
    assert !q.matches?("Is a brush cool stuff?")
    assert !q.matches?("Is paint cool stuff?")
  end

  def test_multi_positive_and_negative_matches_and_processed_input
    q = Query.new 'cool stuff -paint -brush'
    assert q.matches?(%w(stuff thats cool matches))
    assert !q.matches?(%w(is a paint brush cool stuff))
    assert !q.matches?(%w(is a brush cool stuff))
    assert !q.matches?(%(s paint cool stuff))
  end

  def test_multi_positive_and_negative_matches_and_processed_input_as_sets
    q = Query.new 'cool stuff -paint -brush'
    assert q.matches?(Set.new(%w(stuff thats cool matches)))
    assert !q.matches?(Set.new(%w(is a paint brush cool stuff)))
    assert !q.matches?(Set.new(%w(is a brush cool stuff)))
    assert !q.matches?(Set.new(%(s paint cool stuff)))
  end

  def test_positive_and_negative
    q = Query.new 'git -gregkh'
    assert q.matches?("This just talks about git.")
    assert !q.matches?("This just talks about gregkh and git.")
  end

  def test_positive_and_negative_alt
    q = Query.new 'git -gregkh'
    assert q.matches?("This just talks about git.")
    assert !q.matches?("This is about git and (gregkh who logs shell stuff).")
  end


end
