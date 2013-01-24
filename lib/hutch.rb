require 'amqp'

module Hutch
  require 'hutch/consumer'
  require 'hutch/worker'
  require 'hutch/logging'

  def self.register_consumer(consumer)
    self.consumers << consumer
  end

  def self.consumers
    @consumers ||= []
  end

  def self.logger
    Hutch::Logging.logger
  end
end

