module Hutch
  module Acknowledgements
    # Defines acknowledgement handler interface.
    class Base
      # Implements negative acknowledgement/requeueing logic
      # and returns a boolean to indicate whether acknowledgement
      # was performed. If false is returned, next handler in the
      # chain will be invoked.
      #
      # The chain always falls back to unconditional nacking.
      def handle(delivery_info, properties, broker, ex)
        raise NotImplementedError.new
      end
    end
  end
end
