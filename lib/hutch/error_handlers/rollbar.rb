require 'hutch/logging'
require 'rollbar'
require 'hutch/error_handlers/base'

module Hutch
  module ErrorHandlers
    class Rollbar < Base
      def handle(properties, payload, consumer, ex)
        message_id = properties.message_id
        prefix = "message(#{message_id || '-'}):"
        logger.error "#{prefix} Logging event to Rollbar"
        logger.error "#{prefix} #{ex.class} - #{ex.message}"

        ::Rollbar.error(ex,
          payload: payload,
          consumer: consumer
        )
      end

      def handle_setup_exception(ex)
        logger.error "Logging setup exception to Rollbar"
        logger.error "#{ex.class} - #{ex.message}"

        ::Rollbar.error(ex)
      end
    end
  end
end
