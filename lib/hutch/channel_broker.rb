module Hutch
  class ChannelBroker
    include Logging

    attr_accessor :channel, :exchange,
                  :default_wait_exchange, :wait_exchanges

    def initialize(channel)
      @channel = channel
      @wait_exchanges = {}
    end

    def disconnect
      channel.close if channel && channel.active
      @channel = nil
      @exchange = nil
      @default_wait_exchange = nil
      @wait_exchanges = {}
    end

    def reconnect(channel)
      disconnect
      @channel = channel
    end

    def active
      channel && channel.active
    end
  end
end
