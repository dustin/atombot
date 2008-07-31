module AtomBot
  module DeliveryHelper

    def deliver(jid, message, type=:chat)
      u = User.first(:jid => jid)
      if u.nil? || !u.ready_to_receive_message
        puts "... Suppressing send to #{jid}"
      else
        deliver_without_suppression(jid, message, type)
      end
    end

    def deliver_without_suppression(jid, message, type=:chat)
      if message.kind_of?(Jabber::Message)
        msg = message
        msg.to = jid
      else
        msg = Jabber::Message.new(jid)
        msg.type = type
        msg.body = message
      end
      @client.send msg
    end

  end
end
