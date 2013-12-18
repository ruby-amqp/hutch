require 'bunny'
require 'carrot-top'
require 'hutch/logging'
require 'hutch/exceptions'
require 'hutch/broker_handlers/amqp'
require 'hutch/broker_handlers/api'
require 'hutch/broker_handlers/publish'

module Hutch
  class Broker
    include Logging

    attr_accessor :connection, :channel, :exchange, :api_client
    attr_reader   :config

    def initialize(config = nil)
      @config = OpenStruct.new(config || Hutch::Config)
    end

    def connect
      set_up_amqp_connection
      set_up_api_connection

      if block_given?
        yield
        disconnect
      end
    end

    def disconnect
      channel.close    if channel
      connection.close if connection
      @channel, @connection, @exchange, @api_client = nil, nil, nil, nil
    end

    # Connect to RabbitMQ via AMQP. This sets up the main connection and
    # channel we use for talking to RabbitMQ. It also ensures the existance of
    # the exchange we'll be using.
    def set_up_amqp_connection
      with_bunny_rescue do
        logger.info amqp_handler.connection_log_info

        @connection = Bunny.new(amqp_handler.bunny_params)
        connection.start

        logger.info 'opening rabbitmq channel'
        @channel = connection.create_channel

        logger.info amqp_handler.exchange_log_info
        @exchange = channel.topic(amqp_handler.mq_exchange, durable: true)
      end
    end

    # Set up the connection to the RabbitMQ management API. Unfortunately, this
    # is necessary to do a few things that are impossible over AMQP. E.g.
    # listing queues and bindings.
    def set_up_api_connection
      with_api_rescue do
        logger.info api_handler.connection_info

        @api_client = CarrotTop.new(api_handler.carrot_top_params)

        api_client.exchanges
      end
    end

    # Create / get a durable queue.
    def queue(name)
      channel.queue(name, durable: true)
    end

    # Return a mapping of queue names to the routing keys they're bound to.
    def bindings
      results = Hash.new { |hash, key| hash[key] = [] }
      api_client.bindings.each do |binding|
        next if binding['destination'] == binding['routing_key']
        next unless binding['source']  == config.mq_exchange
        next unless binding['vhost']   == config.mq_vhost
        results[binding['destination']] << binding['routing_key']
      end
      results
    end

    # Bind a queue to the broker's exchange on the routing keys provided. Any
    # existing bindings on the queue that aren't present in the array of
    # routing keys will be unbound.
    def bind_queue(queue, routing_keys)
      # Find the existing bindings, and unbind any redundant bindings
      queue_bindings(queue).each do |dest, keys|
        keys.reject { |key| routing_keys.include?(key) }.each do |key|
          logger.debug "removing redundant binding #{queue.name} <--> #{key}"
          queue.unbind(exchange, routing_key: key)
        end
      end

      # Ensure all the desired bindings are present
      routing_keys.each do |routing_key|
        logger.debug "creating binding #{queue.name} <--> #{routing_key}"
        queue.bind(exchange, routing_key: routing_key)
      end
    end

    # Each subscriber is run in a thread. This calls Thread#join on each of the
    # subscriber threads.
    def wait_on_threads(timeout)
      # Thread#join returns nil when the timeout is hit. If any return nil,
      # the threads didn't all join so we return false.
      per_thread_timeout = work_pool_threads.empty? ? 0 : (timeout.to_f / work_pool_threads.length)
      work_pool_threads.none? { |thread| thread.join(per_thread_timeout).nil? }
    end

    def stop
      channel.work_pool.kill
    end

    def ack(delivery_tag)
      channel.ack(delivery_tag, false)
    end

    def publish(routing_key, message, properties = {})
      handler = ::Hutch::BrokerHandlers::Publish.new(connection, routing_key, message, properties)

      if handler.valid_connection?
        logger.info handler.info_message
        exchange.publish(JSON.dump(message), handler.options)
      else
        logger.error handler.error_message
        raise PublishError, handler.error_message
      end
    end

    private

    def work_pool_threads
      channel.work_pool.threads || []
    end

    def with_bunny_rescue(&block)
      yield
    rescue Bunny::TCPConnectionFailed => ex
      logger.error "amqp connection error: #{ex.message.downcase}"
      raise ConnectionError.new(amqp_handler.connection_error)
    rescue Bunny::PreconditionFailed => ex
      logger.error ex.message
      raise WorkerSetupError.new(amqp_handler.worker_setup_error)
    end

    def with_api_rescue(&block)
      yield
    rescue Errno::ECONNREFUSED => ex
      logger.error "api connection error: #{ex.message.downcase}"
      raise ConnectionError.new(api_handler.connection_error)
    rescue Net::HTTPServerException => ex
      logger.error "api connection error: #{ex.message.downcase}"
      if ex.response.code == '401'
        raise AuthenticationError.new('invalid api credentials')
      else
        raise
      end
    end

    def queue_bindings(queue)
      bindings.select { |dest, keys| dest == queue.name }
    end

    def amqp_handler
      @amqp_handler ||= ::Hutch::BrokerHandlers::Amqp.new(config)
    end

    def api_handler
      @api_handler ||= ::Hutch::BrokerHandlers::Api.new(config)
    end
  end
end

