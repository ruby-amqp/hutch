require 'hutch/message'
require 'hutch/logging'
require 'hutch/broker'
require 'carrot-top'

module Hutch
  class Worker
    include Logging

    def initialize(broker, consumers)
      @broker = broker
      raise WorkerSetupError.new('no consumers loaded') if consumers.empty?
      @consumers = consumers
    end

    # Run the main event loop. The consumers will be set up with queues, and
    # process the messages in their respective queues indefinitely. This method
    # never returns.
    def run
      setup_queues

      # Set up signal handlers for graceful shutdown
      register_signal_handlers

      # Take a break from Thread#join every 0.1 seconds to check if we've
      # been sent any signals
      handle_signals until @broker.wait_on_threads(0.1)
    rescue Bunny::PreconditionFailed => ex
      logger.error ex.message
      raise WorkerSetupError.new('could not create queue due to a type ' +
                                 'conflict with an existing queue, remove ' +
                                 'the existing queue and try again')
    end

    # Register handlers for SIG{QUIT,TERM,INT} to shut down the worker
    # gracefully. Forceful shutdowns are very bad!
    def register_signal_handlers
      Thread.main[:signal_queue] = []
      %w(QUIT TERM INT).map(&:to_sym).each do |sig|
        # This needs to be reentrant, so we queue up signals to be handled
        # in the run loop, rather than acting on signals here
        trap(sig) do
          Thread.main[:signal_queue] << sig
        end
      end
    end

    # Handle any pending signals
    def handle_signals
      if sig = Thread.main[:signal_queue].shift
        logger.info "caught sig#{sig.downcase}, stopping hutch..."
        @broker.stop
      end
    end

    # Stop a running worker by killing all subscriber threads.
    def stop
      @broker.stop
    end

    # Set up the queues for each of the worker's consumers.
    def setup_queues
      logger.info 'setting up queues'
      @consumers.each { |consumer| setup_queue(consumer) }
    end

    # Bind a consumer's routing keys to its queue, and set up a subscription to
    # receive messages sent to the queue.
    def setup_queue(consumer)
      queue = @broker.queue(consumer.queue_name)
      @broker.bind_queue(queue, consumer.routing_keys)

      queue.subscribe(ack: true) do |delivery_info, properties, payload|
        handle_message(consumer, delivery_info, properties, payload)
      end
    end

    # Called internally when a new messages comes in from RabbitMQ. Responsible
    # for wrapping up the message and passing it to the consumer.
    def handle_message(consumer, delivery_info, properties, payload)
      logger.info("message(#{properties.message_id || '-'}): " +
                  "routing key: #{delivery_info.routing_key}, " +
                  "consumer: #{consumer}, " +
                  "payload: #{payload}")

      message = Message.new(delivery_info, properties, payload)
      broker = @broker
      begin
        consumer.new.process(message)
        broker.ack(delivery_info.delivery_tag)
      rescue StandardError => ex
        handle_error(message.message_id, consumer, ex)
        broker.ack(delivery_info.delivery_tag)
      end
    end

    def handle_error(message_id, consumer, ex)
      Hutch::Config[:error_handlers].each do |backend|
        backend.handle(message_id, consumer, ex)
      end
    end
  end
end
