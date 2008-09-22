module AtomBot

  module XMPPCommands

    class Base
      attr_reader :node, :name, :description

      def initialize(node, name, description)
        @node=node
        @name=name
        @description=description
      end

      def execute(conn, iq)
        raise "Not Implemented"
      end

      def send_result(conn, iq, status=:completed, &block)
        cmd_node = iq.command.attributes['node']
        i = Jabber::Iq::new(:result, iq.from)
        i.from = AtomBot::Config::SCREEN_NAME
        i.id = iq.id
        com = i.add_element(Jabber::Command::IqCommand::new(cmd_node))
        com.status = status
        yield com
        conn.send i
      end
    end

    class Version < Base

      def initialize
        super('version', 'Version', 'Get the current version of the bot software.')
      end

      def execute(conn, iq)
        send_result(conn, iq) do |com|
          form = com.add_element(Jabber::Dataforms::XData::new('result'))
          v = form.add_element(Jabber::Dataforms::XDataField.new('version', 'text-single'))
          v.value = AtomBot::Config::VERSION
        end
      end

    end

    def self.commands
      constants.map{|c| const_get c}.select {|c| c != Base }
    end
  end

end