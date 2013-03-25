require 'hutch/logging'
require 'raven'

module Hutch
  module ErrorHandlers
    class Sentry
      include Logging

      def handle(message_id, consumer, ex)
        event = Raven::Event.capture_exception(ex)

        # In some cases, it's possible that Raven::Event.capture_exception
        # returns nil, in which case we don't want to log anything
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
