module AtomBot

  module XMPPCommands

    class Base
      attr_reader :node, :name, :description

      def initialize(node, name, description)
        @node=node
        @name=name
        @description=description
      end

      def execute(conn, user, iq)
        raise "Not Implemented"
      end

      def send_result(conn, iq, status=:completed, &block)
        cmd_node = iq.command.attributes['node']
        i = Jabber::Iq::new(:result, iq.from)
        i.from = AtomBot::Config::SCREEN_NAME
        i.id = iq.id
        com = i.add_element(Jabber::Command::IqCommand::new(cmd_node))
        com.status = status
        yield com if block_given?
        conn.send i
      end
    end

    class Version < Base

      def initialize
        super('version', 'Version', 'Get the current version of the bot software.')
      end

      def execute(conn, user, iq)
        send_result(conn, iq) do |com|
          form = com.add_element(Jabber::Dataforms::XData::new('result'))
          v = form.add_element(Jabber::Dataforms::XDataField.new('version', 'text-single'))
          v.value = AtomBot::Config::VERSION
        end
      end

    end

    class AddTrack < Base

      def initialize
        super('track', 'Add a Track', 'Add a track query.')
      end

      def execute(conn, user, iq)
        case iq.command.action
        when :cancel
          send_result(conn, iq, :canceled)
        when nil
          args = iq.command.first_element('x')
          if args.blank?
            send_result(conn, iq, :executing) do |com|
              a = com.add_element("actions")
              a.attributes['execute'] = 'complete'
              a.add_element('prev')
              a.add_element('complete')

              form = com.add_element(Jabber::Dataforms::XData::new)
              form.add_element(Jabber::Dataforms::XDataField.new('query', 'text-single'))
            end
          else
            h=Hash[*args.fields.map {|f| [f.var, f.value]}.flatten]
            user.track h['query'].downcase
            $logger.info("Tracked #{h['query']} for #{user.to_s}")
            send_result(conn, iq)
          end
        end
      end
    end

    def self.commands
      constants.map{|c| const_get c}.select {|c| c != Base }
    end
  end

end