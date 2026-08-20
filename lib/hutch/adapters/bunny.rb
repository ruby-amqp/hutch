require 'bunny'
require 'forwardable'

require 'hutch/logging'

module Hutch
  module Adapters
    class BunnyAdapter
      extend Forwardable
      include Logging

      DEFAULT_VHOST = Bunny::Session::DEFAULT_VHOST

      ConnectionRefused = Bunny::TCPConnectionFailed
      PreconditionFailed = Bunny::PreconditionFailed

      def_delegators :@connection, :start, :disconnect, :close, :create_channel, :open?, :recover_channel_topology

      def initialize(opts={})
        @connection = Bunny.new(opts)
      end

      def self.decode_message(delivery_info, properties, payload)
        [delivery_info, properties, payload]
      end

      def prefetch_channel(ch, prefetch)
        ch.prefetch(prefetch) if prefetch
      end

      def queue_exists?(name)
        @connection.queue_exists?(name)
      end

      def install_channel_recovery(ch)
        # A consumer timeout invalidates the delivery tag, so a handler that
        # was still running acknowledges an unknown tag and closes the channel.
        ch.on_error do |channel, close|
          next unless close.delivery_ack_timeout? || close.unknown_delivery_tag?

          begin
            channel.reopen
            recover_channel_topology(channel)
            logger.warn "recovered consumer channel closed with '#{close.reply_text}'"
          rescue => ex
            logger.error "channel recovery failed: #{ex.class}: #{ex.message}"
          end
        end
      end

      def current_timestamp
        Time.now.to_i
      end

      def self.new_exchange(ch, exchange_type, exchange_name, exchange_options)
        Bunny::Exchange.new(ch, exchange_type, exchange_name, exchange_options)
      end
    end
  end
end
