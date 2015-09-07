module Hutch
  module Tracers
    class NullTracer

      def initialize(klass)
        @klass = klass
      end

      def handle(message)
        @klass.process(message)
      end

    end
  end
end
