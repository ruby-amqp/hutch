require 'hutch/logging'

module Hutch
  module ErrorHandlers
    class Logger
      include Logging

      def initialize(target = Hutch::Logging.logger)
        @target = target
      end

      def logger
        @target
      end

      def handle(message_id, consumer, ex)
        prefix = "message(#{message_id || '-'}): "
        logger.warn prefix + "error in consumer '#{consumer}'"
        logger.warn prefix + "#{ex.class} - #{ex.message}"
        logger.warn (['backtrace:'] + ex.backtrace).join("\n")
      end
    end
  end
end
