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
            AtomBot::Config::CONF['admins'].each do |a|
              deliver a, "[unknown command] #{user.jid}: #{cmd} #{arg}"
            end
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
            if deliver u, arg
              send_msg user, "Sending to #{u.jid}"
            else
              send_msg user, "Suppressed send to #{u.jid}"
            end
          end
        else
          send_msg user, "Sorry, you're not an admin."
        end
      end

      cmd :adm_im do |user, arg|
        if AtomBot::Config::CONF['admins'].include? user.jid
          jid, rest=arg.split(/\s+/, 2)
          msg = Jabber::Message.new jid
          msg.type = :chat
          msg.body = rest
          @client.send msg
          send_msg user, "Sent message to #{jid}"
        else
          send_msg user, "Sorry, you're not an admin."
        end
      end

      cmd :adm_subscribe do |user, jid|
        if AtomBot::Config::CONF['admins'].include? user.jid
          req = Jabber::Presence.new.set_type(:subscribe)
          req.to = jid
          @client.send req
          send_msg user, "Sent sub req to #{jid}"
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
          user.track a.downcase
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
          if user.untrack a.downcase
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

      cmd :add_service, "Add a service you can post to." do |user, arg|
        errmsg="You must supply a service name, username, and password"
        with_arg(user, arg, errmsg) do |sup|
          s, u, p = sup.strip.split(/\s+/, 3)
          if s.nil? || u.nil? || p.nil?
            send_msg user, errmsg
          else
            service_msg(:user => user.id, :type => :setup, :service => s, :username => u, :password => p)
          end
        end
      end
      help_text :add_service, <<-EOF
Add a service you can post to.

Usage:  add_service [svcname] [username] [password]

Example:  add_service identi.ca myusername m3p455w4r6

see "help services" for a list of available services
EOF

      cmd :services, "List all known services." do |user, arg|
        services = Hash[* Service.all.map{|s| [s.name, s]}.flatten]
        userv = Hash[* user.user_services.map{|us| [us.service.name, us]}.flatten]
        userv.keys.each {|k| services.delete k}

        out = []
        unless userv.empty?
          out << "Your Services:"
          out += userv.to_a.sort.map { |k,v| "- #{k} (#{v.login})"}
        end
        unless services.empty?
          out << "Available Services:"
          out += services.keys.sort.map { |k| "- #{k}" }
        end

        send_msg user, out.join("\n")
      end

      cmd :post, "Post an update to a service." do |user, arg|
        with_arg(user, arg, "What do you want to post?") do |msg|
          s = if /^!([A-z.]+)\s(.*)/.match msg
            msg = $2
            $1
          else
            # XXX:  Probably want to look this up per user
            'identi.ca'
          end
          service_msg(:user => user.id, :type => :post, :service => s, :msg => msg)
        end
      end
      help_text :post, <<-EOF
Post an update to a service.

If your message begins with a !, this will post to the specific service,
otherwise your default service will be used.

Examples:
post Hello, identi.ca
post !twitter Hello, twitter.
post !identi.ca Hello, identi.ca
EOF

      private

      def service_msg(msg)
        beanstalk_svc = Beanstalk::Pool.new [AtomBot::Config::CONF['services']['beanstalkd']]
        beanstalk_svc.use AtomBot::Config::CONF['services']['tube']
        beanstalk_svc.yput(msg)
        beanstalk_svc.close
      end

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
