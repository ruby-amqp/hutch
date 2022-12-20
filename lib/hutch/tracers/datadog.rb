require 'ddtrace'
require 'ddtrace/auto_instrument'

module Hutch
  module Tracers
    class Datadog
      def initialize(klass)
        @klass = klass
      end

      def handle(message)
        ::Datadog::Tracing.trace(@klass.class.name, continue_from: nil, service: 'hutch', type: 'rabbitmq') do
          @klass.process(message)
        end
      end
    end
  end
end
