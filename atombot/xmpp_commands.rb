require 'atombot/models'

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

    class MultiBase < Base

      def next_actions(com, execute, *actions)
        ael = com.add_element("actions")
        ael.attributes['execute'] = execute
        actions.each {|a| ael.add_element a}
      end

      def add_field(form, name, label, value=nil, type=:text_single)
        ufield = form.add_element(Jabber::Dataforms::XDataField.new(name, type))
        ufield.label = label
        ufield.value = value.to_s unless value.nil?
        ufield
      end

      def execute(conn, user, iq)
        $logger.info "Executing #{self.class.to_s} for #{user.jid} action=#{iq.command.action.inspect}"
        case iq.command.action
        when :cancel
          send_result(conn, iq, :canceled)
        when nil, :complete
          args = iq.command.first_element('x')
          if args.blank?
            send_result(conn, iq, :executing) do |com|
              add_form(user, iq, com)
            end
          else
            complete(conn, user, iq, args)
          end
        end
      rescue
        send_result(conn, iq) do |com|
          note = com.add_element('note')
          note.attributes['type'] = 'error'
          note.add_text($!.to_s)
          error = com.add_element(Jabber::ErrorResponse.new('bad-request'))
        end
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

    class AddTrack < MultiBase

      def initialize
        super('track', 'Add a Track', 'Add a track query.')
      end

      def add_form(user, iq, com)
        next_actions(com, 'execute', 'complete')
        form = com.add_element(Jabber::Dataforms::XData::new)
        form.title = 'Add a track query.'
        form.instructions = <<-EOF
Track gives you powerful queries delivered in realtime to your IM client.
Example queries:

iphone
iphone -android
iphone android
EOF
        add_field form, 'query', ' Query'
      end

      def complete(conn, user, iq, args)
        puts "Add track complete"
        h=Hash[*args.fields.map {|f| [f.var, f.value]}.flatten]
        user.track h['query'].downcase
        $logger.info("Tracked #{h['query']} for #{user.to_s}")
        send_result(conn, iq)
      end

    end

    class UnTrack < MultiBase

      def initialize
        super('untrack', 'Remove a Track', 'Remove a track query.')
      end

      def add_form(user, iq, com)
        next_actions(com, 'execute', 'complete')

        form = com.add_element(Jabber::Dataforms::XData::new)
        form.title = 'Untrack one or more current tracks.'
        form.instructions = "Select the queries to stop tracking and submit."
        field = form.add_element(Jabber::Dataforms::XDataField.new('torm', :list_multi))
        field.label = 'Tracks'
        field.options = user.tracks.sort_by{|t| t.query}.map{|t| [t.id, t.query]}
      end

      def complete(conn, user, iq, args)
        torm = args.fields.select {|f| f.var == 'torm'}.first
        torm.values.each do |i|
          puts "Untracking #{i}"
          user.untrack i.to_i
        end
        send_result(conn, iq)
      end

    end

    def self.commands
      constants.map{|c| const_get c}.select {|c| c != Base && c != MultiBase }
    end
  end

end