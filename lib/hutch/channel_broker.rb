require 'hutch/logging'
require 'hutch/broker_handlers'

module Hutch
  class ChannelBroker
    include Logging
    include BrokerHandlers

    def initialize(connection, config)
      @connection = connection
      @config = config || Hutch::Config
    end

    def disconnect
      @channel.close if active
      @channel = nil
      @exchange = nil
      @default_wait_exchange = nil
      @wait_exchanges = nil
    end

    def reconnect
      disconnect
      open_channel!
    end

    def channel
      return @channel if active
      reconnect
    end

    def exchange
      return @exchange if active
      reconnect
      @exchange
    end

    def wait_exchanges
      return {} if @config[:mq_wait_exchange].nil?
      reconnect unless active
      @wait_exchanges ||= set_up_wait_exchanges
    end

    def default_wait_exchange
      return nil if @config[:mq_wait_exchange].nil?
      reconnect unless active
      @default_wait_exchange ||= set_up_default_wait_exchange
    end

    def active
      @channel && @channel.active
    end

    def open_channel!
      logger.info 'opening rabbitmq channel'
      @channel = @connection.create_channel.tap do |ch|
        ch.prefetch(@config[:channel_prefetch]) if @config[:channel_prefetch]
        if @config[:publisher_confirms] || @config[:force_publisher_confirms]
          logger.info 'enabling publisher confirms'
          ch.confirm_select
        end

        exchange_name = @config[:mq_exchange]
        logger.info "using topic exchange '#{exchange_name}'"

        with_bunny_precondition_handler('exchange') do
          @exchange = ch.topic(exchange_name, durable: true)
        end
      end
    end

    private

    def set_up_wait_exchanges
      wait_exchange_name = @config[:mq_wait_exchange]
      wait_queue_name = @config[:mq_wait_queue]

      expiration_suffices = (@config[:mq_wait_expiration_suffices] || []).map(&:to_s)

      @wait_exchanges = expiration_suffices.each_with_object({}) do |suffix, hash|
        logger.info "using expiration suffix '_#{suffix}'"

        suffix_exchange = declare_wait_exchange("#{wait_exchange_name}_#{suffix}")
        hash[suffix] = suffix_exchange
        declare_wait_queue(suffix_exchange, "#{wait_queue_name}_#{suffix}")
      end
    end

    def set_up_default_wait_exchange
      wait_exchange_name = @config[:mq_wait_exchange]
      wait_queue_name = @config[:mq_wait_queue]

      logger.info "using fanout wait exchange '#{wait_exchange_name}'"

      @default_wait_exchange = declare_wait_exchange(wait_exchange_name)

      logger.info "using wait queue '#{wait_queue_name}'"

      declare_wait_queue(@default_wait_exchange, wait_queue_name)
      @default_wait_exchange
    end

    def declare_wait_exchange(name)
      with_bunny_precondition_handler('exchange') do
        channel.fanout(name, durable: true)
      end
    end

    def declare_wait_queue(exchange, queue_name)
      with_bunny_precondition_handler('queue') do
        queue = channel.queue(
          queue_name,
          durable: true,
          arguments: { 'x-dead-letter-exchange' => @config[:mq_exchange] }
        )
        queue.bind(exchange)
      end
    end
  end
end
