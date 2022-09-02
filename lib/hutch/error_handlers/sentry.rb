require 'hutch/logging'
require 'sentry-ruby'
require 'hutch/error_handlers/base'

module Hutch
  module ErrorHandlers
    class Sentry < Base
      def handle(properties, payload, consumer, ex)
        message_id = properties.message_id
        prefix = "message(#{message_id || '-'}):"
        logger.error "#{prefix} Logging event to Sentry"
        logger.error "#{prefix} #{ex.class} - #{ex.message}"
        ::Sentry.configure_scope do |scope|
          scope.set_context("payload", JSON.parse(payload))
        end
        ::Sentry.capture_exception(ex)
      end

      def handle_setup_exception(ex)
        logger.error "Logging setup exception to Sentry"
        logger.error "#{ex.class} - #{ex.message}"
        ::Sentry.capture_exception(ex)
      end
    end
  end
end
