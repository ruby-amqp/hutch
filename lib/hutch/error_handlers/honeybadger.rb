require 'hutch/logging'
require 'honeybadger'

module Hutch
  module ErrorHandlers
    # Error handler for the Honeybadger.io service
    class Honeybadger
      include Logging

      def handle(properties, payload, consumer, ex)
        message_id = properties.message_id
        prefix = "message(#{message_id || '-'}):"
        logger.error "#{prefix} Logging event to Honeybadger"
        logger.error "#{prefix} #{ex.class} - #{ex.message}"
        notify_honeybadger(error_class: ex.class.name,
                           error_message: "#{ex.class.name}: #{ex.message}",
                           backtrace: ex.backtrace,
                           context: { message_id: message_id,
                                      consumer: consumer },
                           parameters: { payload: payload })
      end

      # Wrap API to support 3.0.0+
      #
      # @see https://github.com/honeybadger-io/honeybadger-ruby/blob/master/CHANGELOG.md#300---2017-02-06
      def notify_honeybadger(message)
        if ::Honeybadger.respond_to?(:notify_or_ignore)
          ::Honeybadger.notify_or_ignore(message)
        else
          ::Honeybadger.notify(message.merge(force: true))
        end
      end
    end
  end
end
