require 'amqp'
require 'hutch/message'

module Hutch
  class Worker
    def initialize(consumers)
      @consumers = consumers
    end

    # Run the main event loop. The consumers will be set up with queues, and
    # process the messages in their respective queues indefinitely. This method
    # never returns.
    def run
      EventMachine.run do
        @connection = AMQP.connect(host: '127.0.0.1')
        @channel    = AMQP::Channel.new(@connection)
        @exchange   = @channel.topic('hutch.dev')

        setup_queues
      end
    end

    # Set up the queues for each of the worker's consumers.
    def setup_queues
      @consumers.each { |consumer| setup_queue(consumer) }
    end

    # Bind a consumer's routing keys to its queue, and set up a subscription to
    # receive messages sent to the queue.
    def setup_queue(consumer)
      queue = consumer_queue(consumer)

      consumer.routing_keys.each do |routing_key|
        queue.bind(@exchange, routing_key: routing_key)
      end

      queue.subscribe do |metadata, payload|
        handle_message(consumer, metadata, payload)
      end
    end

    # Get / create the RabbitMQ queue for a given consumer.
    def consumer_queue(consumer)
      @channel.queue(consumer.queue_name)
    end

    # Called internally when a new messages comes in from RabbitMQ. Responsible
    # for wrapping up the message and passing it to the consumer.
    def handle_message(consumer, metadata, payload)
      message = Message.new(metadata, payload)
      consumer.new.process(message)
    end
  end
end
