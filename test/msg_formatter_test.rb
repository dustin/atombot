require "test/unit"

require "atombot/msg_formatter"

class QueryTest < Test::Unit::TestCase

  include AtomBot::MsgFormatter

  def test_overall_htmlification_username
    assert_equal %Q{[twitter] <a href="http://twitter.com/me">me</a>: yo, <a href="http://twitter.com/blah">@blah</a>},
      format_html_body("me", "yo, @blah", nil, "twitter")
  end

  def test_overall_htmlification_tag_twitter
    assert_equal %Q{[twitter] <a href="http://twitter.com/me">me</a>: check out #thing},
      format_html_body("me", 'check out #thing', nil, "twitter")
  end

  def test_overall_htmlification_tag_identica
    assert_equal %Q{[identica] <a href="http://identi.ca/me">me</a>: check out <a href="http://identi.ca/tag/thing">#thing</a>},
      format_html_body("me", 'check out #thing', nil, "identica")
  end

  def test_user_html_twitter
    assert_equal %Q{yo, <a href="http://twitter.com/blah">@blah</a>},
      format_html_users("yo, @blah", "twitter")
  end

  def test_user_html_identica
    assert_equal %Q{yo, <a href="http://identi.ca/blah">@blah</a>},
      format_html_users("yo, @blah", "identica")
  end

  def test_tag_html_identica
    assert_equal %Q{check out <a href="http://identi.ca/tag/blah">#blah</a>},
      format_html_tags("check out #blah", "identica")
  end

  def test_tag_html_twitter
    assert_equal %Q{check out #blah},
      format_html_tags("check out #blah", "twitter")
  end

end