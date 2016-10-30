require 'opbeat'

module Hutch
  module Tracers
    # Tracer for Opbeat, which traces each message processed.
    class Opbeat
      KIND = 'messaging.hutch'.freeze

      # @param klass [Consumer] Consumer instance (!)
      def initialize(klass)
        @klass = klass
      end

      # @param message [Message]
      def handle(message)
        ::Opbeat.transaction(sig, KIND, extra: extra_from(message)) do
          @klass.process(message)
        end.done(true)
      end

      private

      def sig
        @klass.class.name
      end

      def extra_from(message)
        {
          body: message.body.to_s,
          message_id: message.message_id,
          timestamp: message.timestamp,
          routing_key: message.routing_key
        }
      end
    end
  end
end
