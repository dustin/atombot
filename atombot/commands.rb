require 'rubygems'

require 'atombot/delivery_helper'

module AtomBot
  module Commands

    class Help
      attr_accessor :short_help, :full_help

      def initialize(short_help)
        @short_help = @full_help = short_help
      end

      def to_s
        @short_help
      end
    end

    module CommandDefiner

      def all_cmds
        @@all_cmds ||= {}
      end

      def cmd(name, help=nil, &block)
        unless help.nil?
          all_cmds()[name.to_s] = AtomBot::Commands::Help.new help
        end
        define_method(name, &block)
      end

      def help_text(name, text)
        all_cmds()[name.to_s].full_help = text
      end

    end

    class CommandProcessor

      extend CommandDefiner
      include AtomBot::DeliveryHelper

      def initialize(conn)
        @client = conn
      end

      def typing_notification(user)
        @client.send("<message
            from='#{Config::SCREEN_NAME}'
            to='#{user.jid}'>
            <x xmlns='jabber:x:event'>
              <composing/>
            </x></message>")
      end

      def dispatch(cmd, user, arg)
        # I have a bunch of these guys in error state beating up my bot.
        return if user.status == 'error'
        typing_notification user
        if self.respond_to? cmd
          self.send cmd.to_sym, user, arg
        else
          if user.auto_post
            post user, "#{cmd} #{arg}"
          else
            out = ["I don't understand '#{cmd}'."]
            # out << "Send 'help' for known commands."
            # out << "If you intended this to be posted, see 'help autopost'"
            send_msg user, out.join("\n")
          end
        end
      end

      def send_msg(user, text)
        deliver_without_suppression user, text
      end

      cmd :help, "Get help for commands." do |user, arg|
        cmds = self.class.all_cmds()
        if arg.blank?
          out = ["Available commands:"]
          out << "Type `help somecmd' for more help on `somecmd'"
          out << ""
          out << cmds.keys.sort.map{|k| "#{k}\t#{cmds[k]}"}
          out << ""
          out << "Email questions, suggestions or complaints to dustin@spy.net"
          send_msg user, out.join("\n")
        else
          h = cmds[arg]
          if h
            out = ["Help for `#{arg}'"]
            out << h.full_help
            send_msg user, out.join("\n")
          else
            send_msg user, "Topic #{arg} is unknown.  Type `help' for known commands."
          end
        end
      end

      cmd :broadcast do |user, arg|
        if AtomBot::Config::CONF['admins'].include? user.jid
          User.all.each do |u|
            send_msg user, "Sending to #{u.jid}"
            send_msg u, arg
          end
        else
          send_msg user, "Sorry, you're not an admin."
        end
      end

      cmd :version do |user, nothing|
        out = ["Running version #{AtomBot::Config::VERSION}"]
        send_msg user, out.join("\n")
      end

      cmd :on, "Activate updates." do |user, nothing|
        change_user_active_state(user, true)
        send_msg user, "Marked you active."
      end

      cmd :off, "Disable updates." do |user, nothing|
        change_user_active_state(user, false)
        send_msg user, "Marked you inactive."
      end

      cmd :track, "Track a topic" do |user, arg|
        with_arg(user, arg) do |a|
          user.track a
          send_msg user, "Tracking #{a}"
        end
      end
      help_text :track, <<-EOF
Track gives you powerful queries delivered in realtime to your IM client.
Example queries:

track iphone
track iphone -android
track iphone android
EOF

      cmd :untrack, "Stop tracking a topic" do |user, arg|
        with_arg(user, arg) do |a|
          if user.untrack a
            send_msg user, "Stopped tracking #{a}"
          else
            send_msg user, "Didn't stop tracking #{a} (are you sure you were tracking it?)"
          end
        end
      end
      help_text :untrack, <<-EOF
Untrack tells atombot to stop tracking the given query.
Examples:

untrack iphone
untrack iphone -android
untrack iphone android
EOF

      cmd :tracks, "List your tracks." do |user, arg|
        tracks = user.tracks.map{|t| t.query}.sort
        send_msg user, "Tracking #{tracks.size} topics\n" + tracks.join("\n")
      end

      private

      def logged_in?(user)
        !(user.username.blank? || user.password.blank?)
      end

      def with_arg(user, arg, missing_text="Please supply an argument")
        if arg.nil? || arg.strip == ""
          send_msg user, missing_text
        else
          yield arg.strip
        end
      end

      def change_user_active_state(user, to)
        if user.active != to
          user.active = to
          user.save
        end
      end

    end # CommandProcessor

  end
end
