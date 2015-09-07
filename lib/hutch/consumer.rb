require 'set'

module Hutch
  # Include this module in a class to register it as a consumer. Consumers
  # gain a class method called `consume`, which should be used to register
  # the routing keys a consumer is interested in.
  module Consumer
    attr_accessor :broker, :delivery_info

    def self.included(base)
      base.extend(ClassMethods)
      Hutch.register_consumer(base)
    end

    def reject!
      broker.reject(delivery_info.delivery_tag)
    end

    def requeue!
      broker.requeue(delivery_info.delivery_tag)
    end

    def logger
      Hutch::Logging.logger
    end

    module ClassMethods
      # Add one or more routing keys to the set of routing keys the consumer
      # wants to subscribe to.
      def consume(*routing_keys)
        @routing_keys = self.routing_keys.union(routing_keys)
      end

      # Explicitly set the queue name
      def queue_name(name)
        @queue_name = name
      end

      # Allow to specify custom arguments that will be passed when creating the queue.
      def arguments(arguments = {})
        @arguments = arguments
      end

      # Set custom serializer class, override global value
      def serializer(name)
        @serializer = name
      end

      # The RabbitMQ queue name for the consumer. This is derived from the
      # fully-qualified class name. Module separators are replaced with single
      # colons, camelcased class names are converted to snake case.
      def get_queue_name
        return @queue_name unless @queue_name.nil?
        queue_name = self.name.gsub(/::/, ':')
        queue_name.gsub!(/([^A-Z:])([A-Z])/) { "#{Regexp.last_match[1]}_#{Regexp.last_match[2]}" }
        queue_name.downcase
      end

      # Returns consumer custom arguments.
      def get_arguments
        @arguments || {}
      end

      # Accessor for the consumer's routing key.
      def routing_keys
        @routing_keys ||= Set.new
      end

      def get_serializer
        @serializer
      end
    end
  end
end
