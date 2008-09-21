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
            out << "Send 'help' for known commands."
            out << "If you intended this to be posted, see 'help autopost'"
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

      cmd :adm_user_status do |user, jid|
        if AtomBot::Config::CONF['admins'].include? user.jid
          send_msg user, get_status(User.first(:jid => jid)).join("\n")
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

      cmd :status do |user, arg|
        send_msg user, get_status(user).join("\n")
      end

      cmd :track, "Track a topic" do |user, arg|
        with_arg(user, arg) do |a|
          user.track a.downcase
          send_msg(user, "Tracking #{a}\n" +
            "(please wait a minute or two for changes to take effect)")
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
            send_msg(user, "Stopped tracking #{a}\n" +
              "(please wait a minute or two for changes to take effect)")
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
        out = ["Tracking #{tracks.size} topics"] + tracks
        global_tracks = user.user_global_filters.map{|t| t.word}.sort
        unless global_tracks.empty?
          out << "\nGlobal stop words:"
          out += global_tracks
        end
        send_msg user, out.join("\n")
      end
      alias_method :tracking, :tracks
      alias_method :stops, :tracks

      cmd :add_stop, "Add a stop word (global negative filter)" do |user, arg|
        with_arg(user, arg) do |a|
          raise "You can't have spaces in a stop word (currently)" if /\s/ === arg
          user.stop a.downcase
          send_msg(user, "Added #{a} to the stop list\n" +
            "(please wait a minute or two for changes to take effect)")
        end
      end
      alias_method :addstop, :add_stop
      help_text :add_stop, <<-EOF
Add a global stop word to apply to all tracks.

Usage:  add_stop [word]

Examples:
  add_stop from:annoying_guy
  add_stop stupid

See also: remove_stop
EOF

      cmd :remove_stop, "Remove a stop word (global negative filter)" do |user, arg|
        with_arg(user, arg) do |a|
          if user.unstop a.downcase
            send_msg(user, "No longer treating #{a} as a stop word\n" +
              "(please wait a minute or two for changes to take effect)")
          else
            send_msg user, "Didn't stop tracking #{a} (are you sure you were tracking it?)"
          end
        end
      end
      alias_method :removestop, :remove_stop
      help_text :remove_stop, <<-EOF
Remove a global stop word.

Usage:  remove_stop [word]

Example:
  remove_stop from:annoying_guy
  remove_stop stupid

See also: add_stop
EOF

      cmd :add_service, "Add a service you can post to." do |user, arg|
        errmsg="You must supply a service name, username, and password"
        with_arg(user, arg, errmsg) do |sup|
          s, u, p = sup.strip.split(/\s+/, 3)
          if s.nil? || u.nil? || p.nil?
            send_msg user, errmsg
          else
            service_msg('user' => user.id, 'type' => 'setup', 'service' => s, 'username' => u, 'password' => p)
          end
        end
      end
      alias_method :addservice, :add_service
      help_text :add_service, <<-EOF
Add a service you can post to.

Usage:  add_service [svcname] [username] [password]

Example:  add_service identica myusername m3p455w4r6

see "services" for a list of available services
EOF

      cmd :set_default_service, "Set your default posting service." do |user, arg|
        errmsg="You must specify the default service name."
        with_arg(user, arg, "You must specify the default service name.") do |sname|
          s = Service.first(:name => sname) || raise("No such service: #{sname}")
          user.default_service_id = s.id
          user.save
          send_msg user, ":) Your default service has been set."
        end
      end
      alias_method :setdefaultservice, :set_default_service
      alias_method :set_defaultservice, :set_default_service
      alias_method :set_defaultservice, :set_default_service
      help_text :set_default_service, <<-EOF
Set your default posting services for posts.

Usage: set_default_service [service_name]

Example: set_default_service twitter

see "services" for a list of available services
EOF

      cmd :services, "List all known services." do |user, arg|
        services = Hash[* Service.all(:listed => true).map{|s| [s.name, s]}.flatten]
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

      cmd :remove_service, "Remove (log out of) a service." do |user, arg|
        with_arg(user, arg, "What service do you want to remove?") do |svcname|
          svc = Service.first(:name => svcname)
          if svc.nil?
            send_msg user, ":( Unknown service #{svcname}"
          else
            userv = user.user_services.first(:service_id => svc.id)
            if userv.nil?
              send_msg user, ":| You were not registered for #{svcname}"
            else
              userv.destroy
              send_msg user, ":) Unregistered from #{svcname}"
            end
          end
        end
      end
      alias_method :removeservice, :remove_service

      cmd :post, "Post an update to a service." do |user, arg|
        with_arg(user, arg, "What do you want to post?") do |msg|
          s = if /^!([A-z.]+)\s(.*)/.match msg
            msg = $2
            $1
          else
            user.default_service.name
          end
          service_msg('user' => user.id, 'type' => 'post', 'service' => s, 'msg' => msg)
        end
      end
      help_text :post, <<-EOF
Post an update to a service.

If your message begins with a !, this will post to the specific service,
otherwise your default service will be used.

Examples:
post Hello, identi.ca
post !twitter Hello, twitter.
post !identica Hello, identi.ca
EOF

      cmd :autopost, "Enable or disable autopost" do |user, arg|
        with_arg(user, arg, "Use 'off' or 'on' to disable or enable autoposting") do |a|
          newval = case arg.downcase
          when "on"
            true
          when "off"
            false
          else
            raise "Autopost must be set to on or off"
          end
          user.update_attributes(:auto_post => newval)
          send_msg user, "Autoposting is now #{newval ? 'on' : 'off'}"
        end
      end
      alias_method :auto_post, :autopost
      help_text :autopost, <<-EOF
Autopost allows you to post by sending any unknown command.
usage:  'autopost on' or 'autopost off'

When autopost is on, any message that doesn't look like a command is posted.
Note that the 'post' command still exists in case you want to post something
that looks like a command.
EOF

      private

      def feed_for(user)
        "#{AtomBot::Config::CONF['web']['atom']}#{user.id}"
      end

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

      def get_status(user)
        out = ["Jid:  #{user.jid}"]
        out << "Jabber Status:  #{user.status}"
        out << "IdentiSpy state:  #{user.active ? 'Active' : 'Not Active'}"
        out << "You are currently tracking #{user.tracks.size} topics."
        out << "Your feed is currently available at #{feed_for user}"
        unless user.default_service_id.nil?
          out << "Default posting service:  #{user.default_service.name}"
        end
        out
      end

    end # CommandProcessor
  end
end
