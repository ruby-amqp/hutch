require 'hutch/message'
require 'hutch/logging'
require 'hutch/broker'
require 'carrot-top'
require 'thread'

module Hutch
  class Worker
    include Logging

    def initialize(broker, consumers)
      @broker        = broker
      self.consumers = consumers
    end

    # Run the main event loop. The consumers will be set up with queues, and
    # process the messages in their respective queues indefinitely. This method
    # never returns.
    def run
      # Set up signal handlers for graceful shutdown
      register_signal_handlers

      register_action_handlers

      setup_queues

      # Take a break from Thread#join every 0.1 seconds to check if we've
      # been sent any actions or signals
      until @broker.wait_on_threads(0.1)
        handle_actions
        handle_signals
        main_loop
      end
    end

    def main_loop
      if defined?(JRUBY_VERSION)
        # Binds shutdown listener to notify main thread if channel was closed
        bind_shutdown_handler

        handle_signals until shutdown_not_called?(0.1)
      else
        # Take a break from Thread#join every 0.1 seconds to check if we've
        # been sent any signals
        handle_signals until @broker.wait_on_threads(0.1)
      end
    end

    # Register handlers for SIG{QUIT,TERM,INT} to shut down the worker
    # gracefully. Forceful shutdowns are very bad!
    def register_signal_handlers
      Thread.main[:signal_queue] = []
      %w(QUIT TERM INT).keep_if { |s| Signal.list.keys.include? s }.map(&:to_sym).each do |sig|
        # This needs to be reentrant, so we queue up signals to be handled
        # in the run loop, rather than acting on signals here
        trap(sig) do
          Thread.main[:signal_queue] << sig
        end
      end
    end

    # Handle any pending signals
    def handle_signals
      signal = Thread.main[:signal_queue].shift
      if signal
        logger.info "caught sig#{signal.downcase}, stopping hutch..."
        stop
      end
    end

    # Register action queue for acknowledging messages in main thread
    # Messages consumed come from main thread so acks and nacks need to use the
    # same channel
    def register_action_handlers
      Thread.main[:action_queue] = Queue.new
    end

    # Handle all pending message acknowledgement actions
    def handle_actions
      until Thread.main[:action_queue].empty?
        action, delivery_tag = Thread.main[:action_queue].pop
        @broker.public_send(action, delivery_tag)
      end
    end

    # Stop a running worker by killing all subscriber threads.
    def stop
      @broker.stop
    end

    # Binds shutdown handler, called if channel is closed or network Failed
    def bind_shutdown_handler
      @broker.channel.on_shutdown do
        Thread.main[:shutdown_received] = true
      end
    end

    # Checks if shutdown handler was called, then sleeps for interval
    def shutdown_not_called?(interval)
      if Thread.main[:shutdown_received]
        true
      else
        sleep(interval)
        false
      end
    end

    # Set up the queues for each of the worker's consumers.
    def setup_queues
      logger.info 'setting up queues'
      @consumers.each { |consumer| setup_queue(consumer) }
    end

    # Bind a consumer's routing keys to its queue, and set up a subscription to
    # receive messages sent to the queue.
    def setup_queue(consumer)
      queue = @broker.queue(consumer.get_queue_name, consumer.get_arguments)
      @broker.bind_queue(queue, consumer.routing_keys)

      queue.subscribe(manual_ack: true) do |*args|
        delivery_info, properties, payload = Hutch::Adapter.decode_message(*args)
        handle_message(consumer, delivery_info, properties, payload)
      end
    end

    # Called internally when a new messages comes in from RabbitMQ. Responsible
    # for wrapping up the message and passing it to the consumer.
    def handle_message(consumer, delivery_info, properties, payload)
      broker = @broker
      begin
        serializer = consumer.get_serializer || Hutch::Config[:serializer]
        logger.info {
          spec   = serializer.binary? ? "#{payload.bytesize} bytes" : "#{payload}"
          "message(#{properties.message_id || '-'}): " +
          "routing key: #{delivery_info.routing_key}, " +
          "consumer: #{consumer}, " +
          "payload: #{spec}"
        }

        message = Message.new(delivery_info, properties, payload, serializer)
        consumer_instance = consumer.new.tap { |c| c.broker, c.delivery_info = @broker, delivery_info }
        with_tracing(consumer_instance).handle(message)
        broker.ack(delivery_info.delivery_tag)
      rescue StandardError => ex
        Thread.main[:action_queue] << [:nack, delivery_info.delivery_tag]
        handle_error(properties.message_id, payload, consumer, ex)
      end
    end

    def with_tracing(klass)
      Hutch::Config[:tracer].new(klass)
    end

    def handle_error(message_id, payload, consumer, ex)
      Hutch::Config[:error_handlers].each do |backend|
        backend.handle(message_id, payload, consumer, ex)
      end
    end

    def consumers=(val)
      if val.empty?
        logger.warn "no consumer loaded, ensure there's no configuration issue"
      end
      @consumers = val
    end
  end
end
