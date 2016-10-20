require 'logger'
require 'time'

module Hutch
  module Logging
    class HutchFormatter < Logger::Formatter
      def call(severity, time, program_name, message)
        "#{time.utc.iso8601} #{Process.pid} #{severity} -- #{message}\n"
      end
    end

    def self.setup_logger
      require 'hutch/config'
      @logger = Logger.new($stdout).tap do |l|
        l.level = Hutch::Config.log_level
        l.formatter = HutchFormatter.new
      end
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
