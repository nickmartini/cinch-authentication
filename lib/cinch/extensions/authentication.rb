require 'cinch/configuration/authentication'

module Cinch
  module Extensions
    module Authentication
      module ClassMethods
        # Public: Enables authentication for the full plugin.
        def enable_authentication
          hook :pre, :for => [:match], :method => :authenticated?
        end
      end

      def self.included(base)
        base.extend ClassMethods
      end

      # Public: Checks if the user is authorized to run the command.
      #
      # m      - The Cinch::Message.
      # levels - The level(s) of authentication Symbol(s) the user must have
      #          (default: nil). See the examples.
      #
      # Examples
      # 
      #   # The :channel_status strategy
      #   authenticated? m, :h # => true for :q, :a, :o and :h
      #   authenticated? m, :o # => true for :q, :a and :o
      #   
      #   # The :user_list and :user_login strategy
      #   authenticated? m, [:admins, :users]
      #   authenticated? m, :admins
      #
      # Returns a Boolean.
      def authenticated?(m, levels = nil)
        strategy = config[:authentication_strategy] || 
          bot.config.authentication.strategy
        levels   = levels || config[:authentication_level] ||
          bot.config.authentication.level

        case strategy
          when :channel_status then return _channel_status_strategy m, levels
          when :user_list then return _user_list_strategy m, levels
          when :user_login then return _user_login_strategy m, levels
          when :channel_status then return channel_status_strategy m, levels
          when :user_list then return user_list_strategy m, levels
          when :user_login then return user_login_strategy m, levels
        end

        bot.loggers.error 'You have not configured an authentication ' +
          'strategy.'
        return false
      end

      # Internal: Checks if the user is an operator on the channel.
      #
      # m     - The Cinch::Message.
      # level - The level Symbol (default: :o).
      def channel_status_strategy(m, level = :o)
        if config.has_key? :authentication_channel
          channel = Channel channel[:authentication_channel]
        elsif bot.config.authentication.channel
          channel = Channel bot.config.authentication.channel
        else
          channel = m.channel
        end

        user_modes = channel.users[m.user]
        modes      = { q: 'founder', a: 'admin', o: 'operator',
          h: 'half-operator', v: 'voice' }

        modes.keys.take(modes.keys.find_index(level) + 1).each do |mode|
          return true if user_modes.include? mode.to_s
        end

        m.user.notice "This command requires at least #{modes[level]} status " +
         "on #{channel}."
        
        return false
      end

      # Internal: Checks if the user sending the message is on the user list.
      #
      # m      - The Cinch::Message.
      # levels - The level Symbol(s).
      #
      # Returns a Boolean.
      def user_list_strategy(m, levels)
        unless m.user.authed?
          m.user.notice "This command requires you to be authenticated."
          return false
        end

        user_list = Array(levels).each_with_object [] do |level, list|
          list.concat(config[level] || bot.config.authentication.send(level))
        end

        bot.loggers.debug user_list.inspect
        
        if user_list.nil?
          bot.loggers.debug "You have not configured any user lists."
        end

        unless user_list.include? m.user.nick
          m.user.notice "You are not authorized to run this command."
          return false
        end

        return true
      end
    end
  end
end