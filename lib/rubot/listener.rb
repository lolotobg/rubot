module Rubot
  class Listener < SlackRubyBot::Commands::Base
    def self.listen_for(regex)
      match regex do |client, data, match|
        begin
          user    = client.users[data.user].name
          channel = client.channels[data.channel] || data.channel

          Rubot.logger.debug "Handle '#{data.text}' from @#{user} in ##{channel}"

          yield client, data, match
        rescue StandardError => error
          raise if Rubot.environment == 'test'

          client.say channel: data.channel,
                     text: Response.error(error.message)

          Rubot.logger.error "Unknown error while handling message: #{error}"
        end
      end
    end

    # Monkey-patch to allow custom bot name handling
    def self.invoke(client, data)
      self.finalize_routes!

      expression, text = parse(client, data)
      expression = expression && expression.strip.gsub(/\s+/, ' ')
      called = false

      routes.each_pair do |route, method|
        match = route.match(expression)
        match ||= route.match(text) if text

        next unless match
        next if match.names.include?('bot') &&
                !Rubot::Bot.replies_to?(match['bot'], data.channel) &&
                match['bot'] != client.name

        called = true

        if method
          method.call(client, data, match)
        elsif self.respond_to?(:call)
          send(:call, client, data, match)
        else
          fail NotImplementedError, data.text
        end

        break
      end

      called
    end
  end
end
