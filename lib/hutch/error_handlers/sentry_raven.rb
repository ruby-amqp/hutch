require 'hutch/logging'
require 'raven'
require 'hutch/error_handlers/base'

module Hutch
  module ErrorHandlers
    class SentryRaven < Base

      def initialize
        unless Raven.respond_to?(:capture_exception)
          raise "The Hutch Sentry error handler requires Raven >= 0.4.0"
        end
      end

      def handle(properties, payload, consumer, ex)
        message_id = properties.message_id
        prefix = "message(#{message_id || '-'}):"
        logger.error "#{prefix} Logging event to Sentry"
        logger.error "#{prefix} #{ex.class} - #{ex.message}"
        Raven.capture_exception(ex, extra: { payload: payload })
      end

      def handle_setup_exception(ex)
        logger.error "Logging setup exception to Sentry"
        logger.error "#{ex.class} - #{ex.message}"
        Raven.capture_exception(ex)
      end

    end
  end
end
