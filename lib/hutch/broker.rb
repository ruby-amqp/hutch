require 'active_support/core_ext/object/blank'

require 'carrot-top'
require 'hutch/logging'
require 'hutch/exceptions'
require 'hutch/publisher'

module Hutch
  class Broker
    include Logging

    attr_accessor :connection, :channel, :exchange, :api_client


    DEFAULT_AMQP_PORT =
      case RUBY_ENGINE
      when "jruby" then
        com.rabbitmq.client.ConnectionFactory::DEFAULT_AMQP_PORT
      when "ruby" then
        AMQ::Protocol::DEFAULT_PORT
      end

    DEFAULT_AMQPS_PORT =
      case RUBY_ENGINE
      when "jruby" then
        com.rabbitmq.client.ConnectionFactory::DEFAULT_AMQP_OVER_SSL_PORT
      when "ruby" then
        AMQ::Protocol::TLS_PORT
      end


    # @param config [nil,Hash] Configuration override
    def initialize(config = nil)
      @config = config || Hutch::Config
    end

    # Connect to broker
    #
    # @example
    #   Hutch::Broker.new.connect(enable_http_api_use: true) do
    #     # will disconnect after this block
    #   end
    #
    # @param [Hash] options The options to connect with
    # @option options [Boolean] :enable_http_api_use
    def connect(options = {})
      @options = options
      set_up_amqp_connection
      if http_api_use_enabled?
        logger.info "HTTP API use is enabled"
        set_up_api_connection
      else
        logger.info "HTTP API use is disabled"
      end

      if tracing_enabled?
        logger.info "tracing is enabled using #{@config[:tracer]}"
      else
        logger.info "tracing is disabled"
      end

      if block_given?
        begin
          yield
        ensure
          disconnect
        end
      end
    end

    def disconnect
      @channel.close    if @channel
      @connection.close if @connection
      @channel = nil
      @connection = nil
      @exchange = nil
      @api_client = nil
    end

    # Connect to RabbitMQ via AMQP
    #
    # This sets up the main connection and channel we use for talking to
    # RabbitMQ. It also ensures the existence of the exchange we'll be using.
    def set_up_amqp_connection
      open_connection!
      open_channel!
      declare_exchange!
      declare_publisher!
    end

    def open_connection
      logger.info "connecting to rabbitmq (#{sanitized_uri})"

      connection = Hutch::Adapter.new(connection_params)

      with_bunny_connection_handler(sanitized_uri) do
        connection.start
      end

      logger.info "connected to RabbitMQ at #{connection_params[:host]} as #{connection_params[:username]}"
      connection
    end

    def open_connection!
      @connection = open_connection
    end

    def open_channel
      logger.info "opening rabbitmq channel with pool size #{consumer_pool_size}, abort on exception #{consumer_pool_abort_on_exception}"
      connection.create_channel(nil, consumer_pool_size, consumer_pool_abort_on_exception).tap do |ch|
        connection.prefetch_channel(ch, @config[:channel_prefetch])
        if @config[:publisher_confirms] || @config[:force_publisher_confirms]
          logger.info 'enabling publisher confirms'
          ch.confirm_select
        end
      end
    end

    def open_channel!
      @channel = open_channel
    end

    def declare_exchange(ch = channel)
      exchange_name = @config[:mq_exchange]
      exchange_type = @config[:mq_exchange_type]
      exchange_options = { durable: true }.merge(@config[:mq_exchange_options])
      logger.info "using topic exchange '#{exchange_name}'"

      with_bunny_precondition_handler('exchange') do
        Bunny::Exchange.new(ch, exchange_type, exchange_name, exchange_options)
      end
    end

    def declare_exchange!(*args)
      @exchange = declare_exchange(*args)
    end

    def declare_publisher!
      @publisher = Hutch::Publisher.new(connection, channel, exchange, @config)
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

    def tracing_enabled?
      @config[:tracer] && @config[:tracer] != Hutch::Tracers::NullTracer
    end

    # Create / get a durable queue and apply namespace if it exists.
    def queue(name, arguments = {})
      with_bunny_precondition_handler('queue') do
        namespace = @config[:namespace].to_s.downcase.gsub(/[^-_:\.\w]/, "")
        name = name.prepend(namespace + ":") if namespace.present?
        channel.queue(name, durable: true, arguments: arguments)
      end
    end

    # Return a mapping of queue names to the routing keys they're bound to.
    def bindings
      results = Hash.new { |hash, key| hash[key] = [] }

      filtered = api_client.bindings.
        reject { |b| b['destination'] == b['routing_key'] }.
        select { |b| b['source'] == @config[:mq_exchange] && b['vhost'] == @config[:mq_vhost] }

      filtered.each do |binding|
        results[binding['destination']] << binding['routing_key']
      end

      results
    end

    # Find the existing bindings, and unbind any redundant bindings
    def unbind_redundant_bindings(queue, routing_keys)
      return unless http_api_use_enabled?

      filtered = bindings.select { |dest, keys| dest == queue.name }
      filtered.each do |dest, keys|
        keys.reject { |key| routing_keys.include?(key) }.each do |key|
          logger.debug "removing redundant binding #{queue.name} <--> #{key}"
          queue.unbind(exchange, routing_key: key)
        end
      end
    end

    # Bind a queue to the broker's exchange on the routing keys provided. Any
    # existing bindings on the queue that aren't present in the array of
    # routing keys will be unbound.
    def bind_queue(queue, routing_keys)
      unbind_redundant_bindings(queue, routing_keys)

      # Ensure all the desired bindings are present
      routing_keys.each do |routing_key|
        logger.debug "creating binding #{queue.name} <--> #{routing_key}"
        queue.bind(exchange, routing_key: routing_key)
      end
    end

    def stop
      if defined?(JRUBY_VERSION)
        channel.close
      else
        # Enqueue a failing job that kills the consumer loop
        channel_work_pool.shutdown
        # Give `timeout` seconds to jobs that are still being processed
        channel_work_pool.join(@config[:graceful_exit_timeout])
        # If after `timeout` they are still running, they are killed
        channel_work_pool.kill
      end
    end

    def requeue(delivery_tag)
      channel.reject(delivery_tag, true)
    end

    def reject(delivery_tag, requeue=false)
      channel.reject(delivery_tag, requeue)
    end

    def ack(delivery_tag)
      channel.ack(delivery_tag, false)
    end

    def nack(delivery_tag)
      channel.nack(delivery_tag, false, false)
    end

    def publish(*args)
      @publisher.publish(*args)
    end

    def confirm_select(*args)
      channel.confirm_select(*args)
    end

    def wait_for_confirms
      channel.wait_for_confirms
    end

    # @return [Boolean] True if channel is set up to use publisher confirmations.
    def using_publisher_confirmations?
      channel.using_publisher_confirmations?
    end

    private

    def api_config
      @api_config ||= OpenStruct.new.tap do |config|
        config.host = @config[:mq_api_host]
        config.port = @config[:mq_api_port]
        config.username = @config[:mq_username]
        config.password = @config[:mq_password]
        config.ssl = @config[:mq_api_ssl]
        config.protocol = config.ssl ? "https://" : "http://"
        config.sanitized_uri = "#{config.protocol}#{config.username}@#{config.host}:#{config.port}/"
      end
    end

    def connection_params
      parse_uri

      {}.tap do |params|
        params[:host]               = @config[:mq_host]
        params[:port]               = @config[:mq_port]
        params[:vhost]              = @config[:mq_vhost].presence || Hutch::Adapter::DEFAULT_VHOST
        params[:username]           = @config[:mq_username]
        params[:password]           = @config[:mq_password]
        params[:tls]                = @config[:mq_tls]
        params[:tls_key]            = @config[:mq_tls_key]
        params[:tls_cert]           = @config[:mq_tls_cert]
        params[:verify_peer]        = @config[:mq_verify_peer]
        if @config[:mq_tls_ca_certificates]
          params[:tls_ca_certificates] = @config[:mq_tls_ca_certificates]
        end
        params[:heartbeat]          = @config[:heartbeat]
        params[:connection_timeout] = @config[:connection_timeout]
        params[:read_timeout]       = @config[:read_timeout]
        params[:write_timeout]      = @config[:write_timeout]


        params[:automatically_recover] = @config[:automatically_recover]
        params[:network_recovery_interval] = @config[:network_recovery_interval]

        params[:logger] = @config[:client_logger] if @config[:client_logger]
      end
    end

    def parse_uri
      return if @config[:uri].blank?

      u = URI.parse(@config[:uri])

      @config[:mq_tls]      = u.scheme == 'amqps'
      @config[:mq_host]     = u.host
      @config[:mq_port]     = u.port || default_mq_port
      @config[:mq_vhost]    = u.path.sub(/^\//, "")
      @config[:mq_username] = u.user
      @config[:mq_password] = u.password
    end

    def default_mq_port
      @config[:mq_tls] ? DEFAULT_AMQPS_PORT : DEFAULT_AMQP_PORT
    end

    def sanitized_uri
      p = connection_params
      scheme = p[:tls] ? "amqps" : "amqp"

      "#{scheme}://#{p[:username]}@#{p[:host]}:#{p[:port]}/#{p[:vhost].sub(/^\//, '')}"
    end

    def with_authentication_error_handler
      yield
    rescue Net::HTTPServerException => ex
      logger.error "HTTP API connection error: #{ex.message.downcase}"
      if ex.response.code == '401'
        raise AuthenticationError.new('invalid HTTP API credentials')
      else
        raise
      end
    end

    def with_connection_error_handler
      yield
    rescue Errno::ECONNREFUSED => ex
      logger.error "HTTP API connection error: #{ex.message.downcase}"
      raise ConnectionError.new("couldn't connect to HTTP API at #{api_config.sanitized_uri}")
    end

    def with_bunny_precondition_handler(item)
      yield
    rescue Hutch::Adapter::PreconditionFailed => ex
      logger.error ex.message
      s = "RabbitMQ responded with 406 Precondition Failed when creating this #{item}. " +
          "Perhaps it is being redeclared with non-matching attributes"
      raise WorkerSetupError.new(s)
    end

    def with_bunny_connection_handler(uri)
      yield
    rescue Hutch::Adapter::ConnectionRefused => ex
      logger.error "amqp connection error: #{ex.message.downcase}"
      raise ConnectionError.new("couldn't connect to rabbitmq at #{uri}. Check your configuration, network connectivity and RabbitMQ logs.")
    end

    def channel_work_pool
      channel.work_pool
    end

    def consumer_pool_size
      @config[:consumer_pool_size]
    end

    def consumer_pool_abort_on_exception
      @config[:consumer_pool_abort_on_exception]
    end
  end
end
