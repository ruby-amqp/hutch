require 'hutch/message'
require 'hutch/adapter'

module Hutch
  class MessagePreprocessor
    include Logging

    def self.to_proc(consumer)
      Proc.new do |*message_args|
        new(Hutch.broker, consumer, message_args).call
      end
    end

    def initialize(broker, consumer, message_args)
      self.delivery_info, self.properties, self.payload = Hutch::Adapter.decode_message(*message_args)
      self.consumer = consumer
      self.broker = broker
    end

    # Called internally when a new messages comes in from RabbitMQ. Responsible
    # for wrapping up the message and passing it to the consumer.
    def call
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
      acknowledge_error(ex)
      handle_error(ex)
    end

    private

    attr_accessor :broker, :consumer, :delivery_info, :properties, :payload

    def with_tracing(klass)
      Hutch::Config[:tracer].new(klass)
    end

    def handle_error(ex)
      Hutch::Config[:error_handlers].each do |backend|
        backend.handle(properties.message_id, payload, consumer, ex)
      end
    end

    def acknowledge_error(ex)
      error_acknowledgements.find do |backend|
        backend.handle(delivery_info, properties, broker, ex)
      end
    end

    def error_acknowledgements
      Hutch::Config[:error_acknowledgements] +
        [Hutch::Acknowledgements::NackOnAllFailures.new]
    end
  end
end
