require "test/unit"

require "atombot/msg_formatter"

class QueryTest < Test::Unit::TestCase

  include AtomBot::MsgFormatter

  def test_overall_htmlification
    assert_equal %Q{<a href="http://twitter.com/me">me</a>: yo, <a href="http://twitter.com/blah">@blah</a>},
      format_html_body("me", "yo, @blah", nil, "twitter")
  end

end