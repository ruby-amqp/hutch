module Hutch
  # Include this module in a class to register it as a consumer. Consumers
  # gain a class method called `consume`, which should be used to register
  # the routing keys a consumer is interested in.
  module Consumer
    def self.included(base)
      base.extend(ClassMethods)
      Hutch.register_consumer(base)
    end

    module ClassMethods
      # Add one or more routing keys to the set of routing keys the consumer
      # wants to subscribe to.
      def consume(*routing_keys)
        @routing_keys = self.routing_keys.union(routing_keys)
      end

      # Supply an optional queue namespace to avoid queue naming conflicts and
      # allow easy identification of queues. It will prefix the queue name with 
      # the namesapce followed by a colon, e.g. "service:module:consumer_class".
      # The namespace will be forced to lower case and stripped of any non 
      # word or ":" characters 
      def queue_namespace(namespace)
        @_queue_namespace = namespace.to_s.downcase.gsub(/\W|:/, "") + ":"
      end

      # The RabbitMQ queue name for the consumer. This is derived from the
      # fully-qualified class name. Module separators are replaced with single
      # colons, camelcased class names are converted to snake case.
      def queue_name
        queue_name = self.name.gsub(/::/, ':')
        queue_name.gsub!(/([^A-Z:])([A-Z])/) { "#{$1}_#{$2}" }
        queue_name = queue_name.prepend(@_queue_namespace) if @_queue_namespace
        return queue_name.downcase
      end

      # Accessor for the consumer's routing key.
      def routing_keys
        @routing_keys ||= Set.new
      end
    end
  end
end

