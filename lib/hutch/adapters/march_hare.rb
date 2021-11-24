require 'march_hare'
require 'forwardable'

module Hutch
  module Adapters
    class MarchHareAdapter
      extend Forwardable

      DEFAULT_VHOST = "/"

      ConnectionRefused = MarchHare::ConnectionRefused
      PreconditionFailed = MarchHare::PreconditionFailed

      def_delegators :@connection, :start, :disconnect, :close, :open?

      def initialize(opts = {})
        @connection = MarchHare.connect(opts)
      end

      def self.decode_message(delivery_info, payload)
        [delivery_info, delivery_info.properties, payload]
      end

      def prefetch_channel(ch, prefetch)
        ch.prefetch = prefetch if prefetch
      end

      def create_channel(n = nil, consumer_pool_size = 1, consumer_pool_abort_on_exception = false)
        @connection.create_channel(n)
      end

      def current_timestamp
        Time.now
      end

      def self.new_exchange(ch, exchange_type, exchange_name, exchange_options)
        MarchHare::Exchange.new(ch, exchange_name, exchange_options.merge(type: exchange_type))
      end
    end
  end
end
