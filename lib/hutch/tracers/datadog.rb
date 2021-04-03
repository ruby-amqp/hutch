require 'ddtrace'

module Hutch
  module Tracers
    class Datadog
      def initialize(klass)
        @klass = klass
      end

      def handle(message)
        ::Datadog.tracer.trace(@klass.class.name, service: 'hutch', span_type: 'rabbitmq') do
          @klass.process(message)
        end
      end
    end
  end
end
