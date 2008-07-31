module AtomBot
  module DeliveryHelper

    def resolve_user(recip)
      case recip
        when String
          User.first(:jid => recip)
        when User
          recip
      end
    end

    def deliver(recip, message, type=:chat)
      u = resolve_user(recip)
      if u.nil? || !u.ready_to_receive_message
        puts "... Suppressing send to #{jid}"
        false
      else
        deliver_without_suppression(u, message, type)
        true
      end
    end

    def deliver_without_suppression(recip, message, type=:chat)
      u = resolve_user(recip)
      if message.kind_of?(Jabber::Message)
        msg = message
        msg.to = u.jid
      else
        msg = Jabber::Message.new(u.jid)
        msg.type = type
        msg.body = message
      end
      @client.send msg
    end

  end
end
