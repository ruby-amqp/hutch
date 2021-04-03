require "hutch/logging"
require "bugsnag"
require "hutch/error_handlers/base"

module Hutch
  module ErrorHandlers
    class Bugsnag < Base
      def handle(properties, payload, consumer, ex)
        message_id = properties.message_id
        prefix = "message(#{message_id || "-"}):"
        logger.error "#{prefix} Logging event to Bugsnag"
        logger.error "#{prefix} #{ex.class} - #{ex.message}"

        ::Bugsnag.notify(ex) do |report|
          report.add_tab(:hutch, {
            payload: payload,
            consumer: consumer
          })
        end
      end

      def handle_setup_exception(ex)
        logger.error "Logging setup exception to Bugsnag"
        logger.error "#{ex.class} - #{ex.message}"

        ::Bugsnag.notify(ex)
      end
    end
  end
end
