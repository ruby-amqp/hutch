require 'hutch/logging'
require 'opbeat'

module Hutch
  module ErrorHandlers
    class Opbeat
      include Logging

      def initialize
        unless ::Opbeat.respond_to?(:report)
          raise "The Opbeat error handler requires Opbeat >= 3.0"
        end
      end

      def handle(properties, payload, consumer, ex)
        message_id = properties.message_id
        prefix = "message(#{message_id || '-'}):"
        logger.error "#{prefix} Logging event to Opbeat"
        logger.error "#{prefix} #{ex.class} - #{ex.message}"
        ::Opbeat.report(ex, extra: { payload: payload })
      end
    end
  end
end
