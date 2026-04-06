begin
  require 'datadog'
  require 'datadog/auto_instrument'
rescue LoadError
  require 'ddtrace'
  require 'ddtrace/auto_instrument'
  warn "[DEPRECATION] The ddtrace gem is deprecated and Hutch will require the datadog gem in 2.0. " \
       "Please switch to the datadog gem."
end

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
