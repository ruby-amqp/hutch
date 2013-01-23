require 'amqp'

module Hutch
  require 'hutch/consumer'
  require 'hutch/worker'

  def self.register_consumer(consumer)
    self.consumers << consumer
  end

  def self.consumers
    @consumers ||= []
  end
end

