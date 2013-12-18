require 'securerandom'

module Hutch
  module BrokerHandlers
    class Publish

      attr_reader :connection, :routing_key, :message, :properties

      def initialize(params)
        @connection  = params.fetch :connection
        @routing_key = params.fetch :routing_key
        @message     = params.fetch :message
        properties   = params.fetch :properties
        properties[:message_id] ||= generate_id
        @properties  = properties
      end

      def valid_connection?
        connection && connection.open?
      end

      def options
        { persistent: true }.merge(properties).merge(non_overridable_properties)
      end

      def error_message
        if connection
          "Unable to publish - no connection to broker. " +
          "Message: #{ message.inspect }, Routing key: #{ routing_key }."
        else
          "Unable to publish - no connection to broker. " +
          "Message: #{message.inspect}, Routing key: #{ routing_key }."
        end
      end

      def info_message
        "publishing message '#{message.inspect}' to #{routing_key}"
      end

      private

      def non_overridable_properties
        {
          routing_key:  routing_key,
          timestamp:    Time.now.to_i,
          content_type: 'application/json'
        }
      end

      def generate_id
        SecureRandom.uuid
      end
    end
  end
end
