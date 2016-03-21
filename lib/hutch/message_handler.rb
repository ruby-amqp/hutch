require 'hutch/message'

module Hutch
  class MessageHandler
    include Logging

    def self.call
      new(Hutch.broker)
    end

    def initialize(broker)
      self.broker = broker
    end

    # Called internally when a new messages comes in from RabbitMQ. Responsible
    # for wrapping up the message and passing it to the consumer.
    def call(consumer, delivery_info, properties, payload)
      serializer = consumer.get_serializer || Hutch::Config[:serializer]
      logger.debug {
        spec   = serializer.binary? ? "#{payload.bytesize} bytes" : "#{payload}"
        "message(#{properties.message_id || '-'}): " +
          "routing key: #{delivery_info.routing_key}, " +
          "consumer: #{consumer}, " +
          "payload: #{spec}"
      }

      message = Message.new(delivery_info, properties, payload, serializer)
      consumer_instance = consumer.new.tap { |c| c.broker, c.delivery_info = broker, delivery_info }
      with_tracing(consumer_instance).handle(message)
      broker.ack(delivery_info.delivery_tag)
    rescue => ex
      acknowledge_error(delivery_info, properties, broker, ex)
      handle_error(properties.message_id, payload, consumer, ex)
    end

    attr_accessor :broker

    def with_tracing(klass)
      Hutch::Config[:tracer].new(klass)
    end

    def handle_error(message_id, payload, consumer, ex)
      Hutch::Config[:error_handlers].each do |backend|
        backend.handle(message_id, payload, consumer, ex)
      end
    end

    def acknowledge_error(delivery_info, properties, broker, ex)
      acks = error_acknowledgements +
        [Hutch::Acknowledgements::NackOnAllFailures.new]
      acks.find do |backend|
        backend.handle(delivery_info, properties, broker, ex)
      end
    end

    def error_acknowledgements
      Hutch::Config[:error_acknowledgements]
    end
  end
end
