module AtomBot
  module DeliveryHelper

    def deliver(jid, message, type=:chat)
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