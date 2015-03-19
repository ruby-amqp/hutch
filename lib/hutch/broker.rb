require 'bunny'
require 'carrot-top'
require 'securerandom'
require 'hutch/logging'
require 'hutch/exceptions'

module Hutch
  class Broker
    include Logging

    attr_accessor :connection, :channel, :exchange, :api_client,
                  :default_wait_exchange, :wait_exchanges

    def initialize(config = nil)
      @config = config || Hutch::Config
      @wait_exchanges = {}
    end

    def connect(options = {})
      @options = options
      set_up_amqp_connection
      set_up_wait_exchange unless @config[:mq_wait_exchange].nil?
      if http_api_use_enabled?
        logger.info 'HTTP API use is enabled'
        set_up_api_connection
      else
        logger.info 'HTTP API use is disabled'
      end

      return unless block_given?
      begin
        yield
      ensure
        disconnect
      end
    end

    def disconnect
      @channel.close    if @channel
      @connection.close if @connection
      @channel, @connection, @exchange, @api_client = nil, nil, nil, nil
      @default_wait_exchange, @wait_exchanges = nil, {}
    end

    # Connect to RabbitMQ via AMQP. This sets up the main connection and
    # channel we use for talking to RabbitMQ. It also ensures the existence of
    # the exchange we'll be using.
    def set_up_amqp_connection
      open_connection!
      open_channel!

      exchange_name = @config[:mq_exchange]
      logger.info "using topic exchange '#{exchange_name}'"

      with_bunny_precondition_handler('exchange') do
        @exchange = @channel.topic(exchange_name, durable: true)
      end
    end

    # Set up wait exchange as a fanout with queue
    def set_up_wait_exchange
      wait_exchange_name = @config[:mq_wait_exchange]
      logger.info "using fanout wait exchange '#{wait_exchange_name}'"

      @default_wait_exchange = declare_wait_exchange(wait_exchange_name)

      wait_queue_name = @config[:mq_wait_queue]
      logger.info "using wait queue '#{wait_queue_name}'"

      declare_wait_queue(@default_wait_exchange, wait_queue_name)

      expiration_suffices = (@config[:mq_wait_expiration_suffices] || []).map(&:to_s)

      expiration_suffices.each do |suffix|
        logger.info "using expiration suffix '_#{suffix}'"

        suffix_exchange = declare_wait_exchange("#{wait_exchange_name}_#{suffix}")
        @wait_exchanges[suffix] = suffix_exchange
        declare_wait_queue(suffix_exchange, "#{wait_queue_name}_#{suffix}")
      end
    end

    # rubocop:disable Metrics/AbcSize
    def open_connection!
      if @config[:uri] && !@config[:uri].empty?
        u = URI.parse(@config[:uri])

        @config[:mq_host]     = u.host
        @config[:mq_port]     = u.port
        @config[:mq_vhost]    = u.path.sub(/^\//, '')
        @config[:mq_username] = u.user
        @config[:mq_password] = u.password
      end

      host               = @config[:mq_host]
      port               = @config[:mq_port]
      vhost              = if @config[:mq_vhost] && '' != @config[:mq_vhost]
                             @config[:mq_vhost]
                           else
                             Bunny::Session::DEFAULT_VHOST
                           end
      username           = @config[:mq_username]
      password           = @config[:mq_password]
      tls                = @config[:mq_tls]
      tls_key            = @config[:mq_tls_key]
      tls_cert           = @config[:mq_tls_cert]
      heartbeat          = @config[:heartbeat]
      connection_timeout = @config[:connection_timeout]
      read_timeout       = @config[:read_timeout]
      write_timeout      = @config[:write_timeout]

      protocol           = tls ? 'amqps://' : 'amqp://'
      sanitized_uri      = "#{protocol}#{username}@#{host}:#{port}/#{vhost.sub(/^\//, '')}"
      logger.info "connecting to rabbitmq (#{sanitized_uri})"
      @connection = Bunny.new(host: host, port: port, vhost: vhost,
                              tls: tls, tls_key: tls_key, tls_cert: tls_cert,
                              username: username, password: password,
                              heartbeat: heartbeat, automatically_recover: true,
                              network_recovery_interval: 1,
                              connection_timeout: connection_timeout,
                              read_timeout: read_timeout,
                              write_timeout: write_timeout)

      with_bunny_connection_handler(sanitized_uri) do
        @connection.start
      end

      logger.info "connected to RabbitMQ at #{host} as #{username}"
      @connection
    end
    # rubocop:enable Metrics/AbcSize

    def open_channel!
      logger.info 'opening rabbitmq channel'
      @channel = connection.create_channel.tap do |ch|
        ch.prefetch(@config[:channel_prefetch]) if @config[:channel_prefetch]
        if @config[:publisher_confirms] || @config[:force_publisher_confirms]
          logger.info 'enabling publisher confirms'
          ch.confirm_select
        end
      end
    end

    # Set up the connection to the RabbitMQ management API. Unfortunately, this
    # is necessary to do a few things that are impossible over AMQP. E.g.
    # listing queues and bindings.
    def set_up_api_connection
      logger.info "connecting to rabbitmq HTTP API (#{api_config.sanitized_uri})"

      with_authentication_error_handler do
        with_connection_error_handler do
          @api_client = CarrotTop.new(host: api_config.host, port: api_config.port,
                                      user: api_config.username, password: api_config.password,
                                      ssl: api_config.ssl)
          @api_client.exchanges
        end
      end
    end

    def http_api_use_enabled?
      op = @options.fetch(:enable_http_api_use, true)
      cf = if @config[:enable_http_api_use].nil?
             true
           else
             @config[:enable_http_api_use]
           end

      op && cf
    end

    # Create / get a durable queue and apply namespace if it exists.
    def queue(name)
      with_bunny_precondition_handler('queue') do
        namespace = @config[:namespace].to_s.downcase.gsub(/[^-:\.\w]/, '')
        name = name.prepend(namespace + ':') unless namespace.empty?
        channel.queue(name, durable: true)
      end
    end

    # Return a mapping of queue names to the routing keys they're bound to.
    def bindings
      results = Hash.new { |hash, key| hash[key] = [] }
      @api_client.bindings.each do |binding|
        next if binding['destination'] == binding['routing_key']
        next unless binding['source'] == @config[:mq_exchange]
        next unless binding['vhost'] == @config[:mq_vhost]
        results[binding['destination']] << binding['routing_key']
      end
      results
    end

    # Bind a queue to the broker's exchange on the routing keys provided. Any
    # existing bindings on the queue that aren't present in the array of
    # routing keys will be unbound.
    def bind_queue(queue, routing_keys)
      if http_api_use_enabled?
        # Find the existing bindings, and unbind any redundant bindings
        queue_bindings = bindings.select { |dest, _keys| dest == queue.name }
        queue_bindings.each do |_dest, keys|
          keys.reject { |key| routing_keys.include?(key) }.each do |key|
            logger.debug "removing redundant binding #{queue.name} <--> #{key}"
            queue.unbind(@exchange, routing_key: key)
          end
        end
      end

      # Ensure all the desired bindings are present
      routing_keys.each do |routing_key|
        logger.debug "creating binding #{queue.name} <--> #{routing_key}"
        queue.bind(@exchange, routing_key: routing_key)
      end
    end

    # Each subscriber is run in a thread. This calls Thread#join on each of the
    # subscriber threads.
    def wait_on_threads(timeout)
      # Thread#join returns nil when the timeout is hit. If any return nil,
      # the threads didn't all join so we return false.
      per_thread_timeout = timeout.to_f / work_pool_threads.length
      work_pool_threads.none? { |thread| thread.join(per_thread_timeout).nil? }
    end

    def stop
      @channel.work_pool.kill
    end

    def requeue(delivery_tag)
      @channel.reject(delivery_tag, true)
    end

    def reject(delivery_tag, requeue=false)
      @channel.reject(delivery_tag, requeue)
    end

    def ack(delivery_tag)
      @channel.ack(delivery_tag, false)
    end

    def nack(delivery_tag)
      @channel.nack(delivery_tag, false, false)
    end

    def publish(routing_key, message, properties = {})
      ensure_connection!(routing_key, message)

      non_overridable_properties = {
        routing_key: routing_key,
        timestamp: Time.now.to_i,
        content_type: 'application/json'
      }
      properties[:message_id] ||= generate_id

      json = JSON.dump(message)
      logger.info("publishing message '#{json}' to #{routing_key}")
      response = @exchange.publish(json, { persistent: true }
        .merge(properties)
        .merge(global_properties)
        .merge(non_overridable_properties))

      channel.wait_for_confirms if @config[:force_publisher_confirms]
      response
    end

    def publish_wait(routing_key, message, properties = {})
      ensure_connection!(routing_key, message)
      if @config[:mq_wait_exchange].nil?
        raise_publish_error('wait exchange not defined', routing_key, message)
      end

      non_overridable_properties = {
        routing_key: routing_key,
        content_type: 'application/json'
      }
      properties[:message_id] ||= generate_id
      properties[:timestamp] ||= Time.now.to_i

      message_properties = { persistent: true }
                           .merge(properties)
                           .merge(global_properties)
                           .merge(non_overridable_properties)
      exchange = @wait_exchanges.fetch(message_properties[:expiration].to_s, @default_wait_exchange)
      json = JSON.dump(message)
      logger.info("publishing message '#{json}' to '#{exchange.name}' with routing key '#{routing_key}'")

      response = exchange.publish(json, message_properties)

      channel.wait_for_confirms if @config[:force_publisher_confirms]
      response
    end

    def confirm_select(*args)
      @channel.confirm_select(*args)
    end

    def wait_for_confirms
      @channel.wait_for_confirms
    end

    def using_publisher_confirmations?
      @channel.using_publisher_confirmations?
    end

    private

    def raise_publish_error(reason, routing_key, message)
      msg = "unable to publish - #{reason}. Message: #{JSON.dump(message)}, Routing key: #{routing_key}."
      logger.error(msg)
      raise PublishError, msg
    end

    def ensure_connection!(routing_key, message)
      raise_publish_error('no connection to broker', routing_key, message) unless @connection
      raise_publish_error('connection is closed', routing_key, message) unless @connection.open?
    end

    def api_config
      @api_config ||= OpenStruct.new.tap do |config|
        config.host = @config[:mq_api_host]
        config.port = @config[:mq_api_port]
        config.username = @config[:mq_username]
        config.password = @config[:mq_password]
        config.ssl = @config[:mq_api_ssl]
        config.protocol = config.ssl ? 'https://' : 'http://'
        config.sanitized_uri = "#{config.protocol}#{config.username}@#{config.host}:#{config.port}/"
      end
    end

    def with_authentication_error_handler
      yield
    rescue Net::HTTPServerException => ex
      logger.error "HTTP API connection error: #{ex.message.downcase}"
      if ex.response.code == '401'
        raise AuthenticationError, 'invalid HTTP API credentials'
      else
        raise
      end
    end

    def with_connection_error_handler
      yield
    rescue Errno::ECONNREFUSED => ex
      logger.error "HTTP API connection error: #{ex.message.downcase}"
      raise ConnectionError, "couldn't connect to HTTP API at #{api_config.sanitized_uri}"
    end

    def with_bunny_precondition_handler(item)
      yield
    rescue Bunny::PreconditionFailed => ex
      logger.error ex.message
      s = "RabbitMQ responded with 406 Precondition Failed when creating this #{item}. " \
          'Perhaps it is being redeclared with non-matching attributes'
      raise WorkerSetupError, s
    end

    def with_bunny_connection_handler(uri)
      yield
    rescue Bunny::TCPConnectionFailed => ex
      logger.error "amqp connection error: #{ex.message.downcase}"
      raise ConnectionError, "couldn't connect to rabbitmq at #{uri}. Check your configuration, network connectivity and RabbitMQ logs."
    end

    def work_pool_threads
      @channel.work_pool.threads || []
    end

    def generate_id
      SecureRandom.uuid
    end

    def global_properties
      Hutch.global_properties.respond_to?(:call) ? Hutch.global_properties.call : Hutch.global_properties
    end

    def declare_wait_exchange(name)
      with_bunny_precondition_handler('exchange') do
        @channel.fanout(name, durable: true)
      end
    end

    def declare_wait_queue(exchange, queue_name)
      with_bunny_precondition_handler('queue') do
        queue = @channel.queue(
          queue_name,
          durable: true,
          arguments: { 'x-dead-letter-exchange' => @config[:mq_exchange] }
        )
        queue.bind(exchange)
      end
    end
  end
end
