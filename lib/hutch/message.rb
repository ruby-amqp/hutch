require 'multi_json'
require 'forwardable'

module Hutch
  class Message
    extend Forwardable

    def initialize(delivery_info, properties, payload)
      @delivery_info = delivery_info
      @properties    = properties
      @payload       = payload
      @body          = MultiJson.load(payload, symbolize_keys: true)
    end

    def_delegator :@body, :[]
    def_delegators :@properties, :message_id, :timestamp
    def_delegators :@delivery_info, :routing_key, :exchange

    attr_reader :body

    def to_s
      attrs = { :@body => body.to_s, message_id: message_id,
                timestamp: timestamp, routing_key: routing_key }
      "#<Message #{attrs.map { |k,v| "#{k}=#{v.inspect}" }.join(', ')}>"
    end

    alias_method :inspect, :to_s
  end
end

