require 'hutch/logging'

module Hutch
  module ErrorHandlers
    class Sentry
      include Logging

      def handle(message_id, consumer, ex)
        event = Raven::Event.capture_exception(ex)

        if event
          prefix = "message(#{message_id || '-'}): "
          logger.warn prefix + "Logging event to Sentry"
          logger.warn prefix + "#{ex.class} - #{ex.message}"
          Raven.send(event)
        end
      end
    end
  end
end
