module Hutch
  autoload :Consumer,      'hutch/consumer'
  autoload :Worker,        'hutch/worker'
  autoload :Broker,        'hutch/broker'
  autoload :Logging,       'hutch/logging'
  autoload :Config,        'hutch/config'
  autoload :Message,       'hutch/message'
  autoload :CLI,           'hutch/cli'
  autoload :Version,       'hutch/version'
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

  def self.global_properties=(properties)
    @global_properties = properties
  end

  def self.global_properties
    @global_properties ||= {}
  end

  def self.connect(options = {}, config = Hutch::Config)
    unless connected?
      @broker = Hutch::Broker.new(config)
      @broker.connect(options)
      @connected = true
    end
  end

  def self.broker
    @broker
  end

  def self.connected?
    @connected
  end

  def self.publish(*args)
    broker.publish(*args)
  end
end

