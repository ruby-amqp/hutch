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

  class << self
    def register_consumer(consumer)
      self.consumers << consumer
    end

    def consumers
      @consumers ||= []
    end

    def logger
      Hutch::Logging.logger
    end

    def connect(options = {}, config = Hutch::Config)
      unless connected?
        @broker = Hutch::Broker.new(config)
        @broker.connect options
        @connected = true
      end
    end

    def broker
      @broker
    end

    def connected?
      @connected
    end

    def publish(*args)
      broker.publish(*args)
    end
  end
end

