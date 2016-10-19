require 'logger'
require 'time'

module Hutch
  module Logging
    class HutchFormatter < Logger::Formatter
      def call(severity, time, program_name, message)
        "#{time.utc.iso8601} #{Process.pid} #{severity} -- #{message}\n"
      end
    end

    def self.setup_logger(target = $stdout)
      require 'hutch/config'
      @logger = Logger.new(target)
      @logger.level = Hutch::Config.log_level
      @logger.formatter = HutchFormatter.new
      @logger
    end

    def self.logger
      @logger || setup_logger
    end

    def self.logger=(logger)
      @logger = logger
    end

    def logger
      Hutch::Logging.logger
    end
  end
end
