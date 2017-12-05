require 'hutch/logging'
require 'hutch/error_handlers/base'

module Hutch
  module ErrorHandlers
    class Logger < ErrorHandlers::Base

      def handle(properties, payload, consumer, ex)
        message_id = properties.message_id
        prefix = "message(#{message_id || '-'}):"
        logger.error "#{prefix} error in consumer '#{consumer}'"
        logger.error "#{prefix} #{ex.class} - #{ex.message}"
        logger.error (['backtrace:'] + ex.backtrace).join("\n")
      end

      def handle_setup_exception(ex)
        logger.error "#{ex.class} - #{ex.message}"
        logger.error (['backtrace:'] + ex.backtrace).join("\n")
      end
    end
  end
end
