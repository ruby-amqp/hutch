require 'hutch/logging'
require 'hutch/acknowledgements/base'

module Hutch
  module Acknowledgements
    class NackOnAllFailures < Base
      include Logging

      def handle(delivery_info, properties, broker, ex)
        prefix = "message(#{properties.message_id || '-'}): "
        logger.debug "#{prefix} nacking message"

        broker.nack(delivery_info.delivery_tag)

        true
      end
    end
  end
end
