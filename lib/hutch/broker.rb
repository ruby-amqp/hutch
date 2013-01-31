require 'bunny'
require 'carrot-top'
require 'hutch/logging'

module Hutch
  class Broker
    include Logging

    attr_accessor :connection, :channel, :exchange, :api_client

    def initialize(config = nil)
      @config = config || Hutch::Config
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
      @channel.close    if @channel
      @connection.close if @connection
      @channel, @connection, @exchange, @api_client = nil, nil, nil, nil
    end

    # Connect to RabbitMQ via AMQP. This sets up the main connection and
    # channel we use for talking to RabbitMQ. It also ensures the existance of
    # the exchange we'll be using.
    def set_up_amqp_connection
      host = @config[:mq_host]
      port = @config[:mq_port]
      logger.info "connecting to rabbitmq (#{host}:#{port})"

      @connection = Bunny.new(host: host, port: port)
      @connection.start

      logger.info 'opening rabbitmq channel'
      @channel = @connection.create_channel

      exchange_name = @config[:mq_exchange]
      logger.info "using topic exchange '#{exchange}'"
      @exchange = @channel.topic(exchange_name, durable: true)
    end

    # Set up the connection to the RabbitMQ management API. Unfortunately, this
    # is necessary to do a few things that are impossible over AMQP. E.g.
    # listing queues and bindings.
    def set_up_api_connection
      host = @config[:mq_host]
      port = @config[:mq_api_port]
      user = @config[:mq_api_user]
      password = @config[:mq_api_password]

      management_uri = "http://#{user}:#{password}@#{host}:#{port}/"
      logger.info "connecting to rabbitmq management api (#{management_uri})"

      @api_client = CarrotTop.new(host: host, port: port,
                                  user: user, password: password)
      @api_client.exchanges
    end

    # Create / get a durable queue.
    def queue(name)
      @channel.queue(name, durable: true)
    end

    # Return a mapping of queue names to the routing keys they're bound to.
    def bindings
      results = Hash.new { |hash, key| hash[key] = [] }
      @api_client.bindings.each do |binding|
        next if binding['destination'] == binding['routing_key']
        results[binding['destination']] << binding['routing_key']
      end
      results
    end

    # Bind a queue to the broker's exchange on the routing keys provided. Any
    # existing bindings on the queue that aren't present in the array of
    # routing keys will be unbound.
    def bind_queue(queue, routing_keys)
      # Find the existing bindings, and unbind any redundant bindings
      queue_bindings = bindings.select { |dest, keys| dest == queue.name }
      queue_bindings.each do |dest, keys|
        keys.reject { |key| routing_keys.include?(key) }.each do |key|
          queue.unbind(@exchange, routing_key: key)
        end
      end

      # Ensure all the desired bindings are present
      routing_keys.each do |routing_key|
        queue.bind(@exchange, routing_key: routing_key)
      end
    end
  end
end

