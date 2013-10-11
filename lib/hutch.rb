module Hutch
  autoload :Consumer, 'hutch/consumer'
  autoload :Worker, 'hutch/worker'
  autoload :Broker, 'hutch/broker'
  autoload :Logging, 'hutch/logging'
  autoload :Config, 'hutch/config'
  autoload :ErrorHandlers, 'hutch/error_handlers'

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

