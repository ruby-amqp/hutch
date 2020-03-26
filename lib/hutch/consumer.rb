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
        # these are opt-in
        @queue_mode = nil
        @queue_type = nil
      end

      attr_reader :queue_mode, :queue_type, :initial_group_size

      # Explicitly set the queue name
      def queue_name(name)
        @queue_name = name
      end

      # Explicitly set the queue mode to 'lazy'
      def lazy_queue
        @queue_mode = 'lazy'
      end

      # Explicitly set the queue type to 'classic'
      def classic_queue
        @queue_type = 'classic'
      end

      # Explicitly set the queue type to 'quorum'
      # @param [Hash] options the options params related to quorum queue
      # @option options [Integer] :initial_group_size Initial Replication Factor
      def quorum_queue(options = {})
        @queue_type = 'quorum'
        @initial_group_size = options[:initial_group_size]
      end

      # Configures an optional argument that will be passed when declaring the queue.
      # Prefer using a policy to this DSL: https://www.rabbitmq.com/parameters.html#policies
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
        queue_name.gsub!(/([^A-Z:])([A-Z])/) { "#{$1}_#{$2}" }
        queue_name.downcase
      end

      # Returns consumer custom arguments.
      def get_arguments
        all_arguments = @arguments || {}

        all_arguments['x-queue-mode'] = @queue_mode if @queue_mode
        all_arguments['x-queue-type'] = @queue_type if @queue_type
        all_arguments['x-quorum-initial-group-size'] = @initial_group_size if @initial_group_size

        all_arguments
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

