require 'hutch/logging'
require 'hutch/config'
require 'hutch/message_preprocessor'
require 'hutch/acknowledgements/nack_on_all_failures'

module Hutch
  module Setup
    class Queues
      include Logging

      def self.call
        new(Hutch.broker, Hutch.consumers).call
      end

      def initialize(broker, consumers)
        self.broker = broker
        self.consumers = consumers
      end

      def call
        logger.info 'setting up queues'
        consumers.each { |consumer| setup_queue(consumer) }
      end

      private

      attr_accessor :broker, :consumers

      # Bind a consumer's routing keys to its queue, and set up a subscription to
      # receive messages sent to the queue.
      def setup_queue(consumer)
        queue = broker.queue(consumer.get_queue_name, consumer.get_arguments)
        broker.bind_queue(queue, consumer.routing_keys)

        queue.subscribe(manual_ack: true, &Config[:message_preprocessing_proc].to_proc(consumer))
      end
    end
  end
end
