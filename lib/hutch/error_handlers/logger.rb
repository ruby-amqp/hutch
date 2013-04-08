require 'hutch/logging'

module Hutch
  module ErrorHandlers
    class Logger
      include Logging

      def handle(message_id, consumer, ex)
        prefix = "message(#{message_id || '-'}): "
        logger.error prefix + "error in consumer '#{consumer}'"
        logger.error prefix + "#{ex.class} - #{ex.message}"
        logger.error (['backtrace:'] + ex.backtrace).join("\n")
      end
    end
  end
end
