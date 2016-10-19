require 'hutch/logging'
require 'airbrake'

module Hutch
  module ErrorHandlers
    class Airbrake
      include Logging

      def handle(properties, payload, consumer, ex)
        message_id = properties.message_id
        prefix = "message(#{message_id || '-'}):"
        logger.error "#{prefix} Logging event to Airbrake"
        logger.error "#{prefix} #{ex.class} - #{ex.message}"

        if ::Airbrake.respond_to?(:notify_or_ignore)
          ::Airbrake.notify_or_ignore(ex, {
            error_class: ex.class.name,
            error_message: "#{ ex.class.name }: #{ ex.message }",
            backtrace: ex.backtrace,
            parameters: {
              payload: payload,
              consumer: consumer,
            },
            cgi_data: ENV.to_hash,
          })
        else
          ::Airbrake.notify(ex, {
            payload: payload,
            consumer: consumer,
            cgi_data: ENV.to_hash,
          })
        end
      end
    end
  end
end
