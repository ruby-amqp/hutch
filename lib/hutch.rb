require 'amqp'

module Hutch
  require 'hutch/consumer'
  require 'hutch/worker'
  require 'hutch/logging'

  DEFAULT_CONFIG = {
    rabbitmq_host: 'localhost',
    rabbitmq_port: 5672,
    rabbitmq_exchange: 'hutch',  # TODO: should this be required?
    log_level: Logger::INFO,
  }

  def self.config
    @config ||= DEFAULT_CONFIG.dup
  end

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

