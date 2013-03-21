module Hutch
  require 'hutch/consumer'
  require 'hutch/worker'
  require 'hutch/logging'
  require 'hutch/error_backends/logger'
  require 'hutch/error_backends/sentry'

  def self.register_consumer(consumer)
    self.consumers << consumer
  end

  def self.consumers
    @consumers ||= []
  end

  def self.logger
    Hutch::Logging.logger
  end

  def self.connect(config = Hutch::Config)
    unless connected?
      @broker = Hutch::Broker.new(config)
      @broker.connect
      @connected = true
    end
  end

  def self.broker
    @broker
  end

  def self.connected?
    @connected
  end

  def self.publish(routing_key, message)
    @broker.publish(routing_key, message)
  end
end

