module Hutch
  module ErrorHandlers
    class Base
      include Logging

      def handle(properties, payload, consumer, ex)
        raise NotImplementedError.new
      end

      def handle_setup_exception(ex)
        raise NotImplementedError.new
      end
    end
  end
end
