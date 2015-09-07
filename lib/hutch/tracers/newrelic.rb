require 'newrelic_rpm'

module Hutch
  module Tracers
    class NewRelic
      include ::NewRelic::Agent::Instrumentation::ControllerInstrumentation

      def initialize(klass)
        @klass = klass
      end

      def handle(message)
        @klass.process(message)
      end

      add_transaction_tracer :handle, :category => 'OtherTransaction/HutchConsumer', :path => '#{@klass.class.name}'
    end
  end
end
