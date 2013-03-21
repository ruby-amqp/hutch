module Hutch
  module ErrorBackends
    class Sentry
      def handle(message_id, consumer, ex)
        event = Raven::Event.capture_exception(ex)
        Raven.send(event) if event
      end
    end
  end
end
