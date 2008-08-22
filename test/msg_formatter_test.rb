require "test/unit"

require "atombot/msg_formatter"

class QueryTest < Test::Unit::TestCase

  include AtomBot::MsgFormatter

  def test_overall_htmlification
    assert_equal %Q{<a href="http://twitter.com/me">me</a>: yo, <a href="http://twitter.com/blah">@blah</a>},
      format_html_body("me", "yo, @blah", nil, "twitter")
  end

  def test_user_html_twitter
    assert_equal %Q{yo, <a href="http://twitter.com/blah">@blah</a>},
      format_html_users("yo, @blah", "twitter")
  end

  def test_user_html_identica
    assert_equal %Q{yo, <a href="http://identi.ca/blah">@blah</a>},
      format_html_users("yo, @blah", "identica")
  end

end