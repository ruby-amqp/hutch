require 'forwardable'

module Hutch
  class Message
    extend Forwardable

    attr_reader :delivery_info, :properties, :payload

    def initialize(delivery_info, properties, payload, serializer)
      @delivery_info = delivery_info
      @properties    = properties
      @payload       = payload
      @body          = serializer.decode(payload)
    end

    def_delegator :@body, :[]
    def_delegators :@properties, :message_id, :timestamp
    def_delegators :@delivery_info, :routing_key, :exchange

    attr_reader :body

    def to_s
      attrs = { :@body => body.to_s, message_id: message_id,
                timestamp: timestamp, routing_key: routing_key }
      "#<Message #{attrs.map { |k, v| "#{k}=#{v.inspect}" }.join(', ')}>"
    end

    alias_method :inspect, :to_s
  end
end
