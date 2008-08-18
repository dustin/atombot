module AtomBot

  module MsgFormatter

    def user_link(user, svc)
      linktext=user
      if user[0] == $@ # Does it start with @?
        user = user.gsub(/^@(.*)/, '\1')
      end
      case svc
      when 'twitter'
        %Q{<a href="http://twitter.com/#{user}">#{linktext}</a>}
      when 'identica'
        %Q{<a href="http://identi.ca/#{user}">#{linktext}</a>}
      else
        puts "Unknown service for providing a user link:  #{svc}"
        linktext
      end
    end

    def type_str(type)
      type.nil? ? '' : "[#{type}] "
    end

    def format_html_body(from, text, type, svc)
      user = user_link(from, svc)
      text = text.gsub(/(\W*)(@[\w_]+)/) {|x| $1 + user_link($2, svc)}.gsub(/&/, '&amp;')
      "#{type_str(type)}#{user}: #{text}"
    end

    def format_plain_body(from, text, type)
      "#{type_str(type)}#{from}: #{text}"
    end

    def format_msg(svc, jid, from, text, subject="Track Message", type=nil)
      body = format_plain_body(from, text, type)
      m = Jabber::Message::new(jid, body).set_type(:chat).set_id('1').set_subject(subject)

      # The html itself
      html = format_html_body(from, text, type, svc)
      begin
        REXML::Document.new "<html>#{html}</html>"

        h = REXML::Element::new("html")
        h.add_namespace('http://jabber.org/protocol/xhtml-im')

        # The body part with the correct namespace
        b = REXML::Element::new("body")
        b.add_namespace('http://www.w3.org/1999/xhtml')

        t = REXML::Text.new(html, false, nil, true, nil, %r/.^/ )

        b.add t
        h.add b
        m.add_element(h)
      rescue REXML::ParseException
        puts "Nearly made bad html:  #{$!} (#{text})"
        $stdout.flush
      end

      m
    end

    def format_track_msg(stuff)
      format_msg(stuff[:source], stuff[:to], stuff[:author], stuff[:message])
    end
  end

end