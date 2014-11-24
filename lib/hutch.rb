require 'hutch/consumer'
require 'hutch/worker'
require 'hutch/broker'
require 'hutch/logging'
require 'hutch/config'
require 'hutch/message'
require 'hutch/cli'
require 'hutch/version'
require 'hutch/error_handlers'
require 'hutch/exceptions'

module Hutch

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

  def self.disconnect
    if @broker
      @broker.disconnect
      @connected = false
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

