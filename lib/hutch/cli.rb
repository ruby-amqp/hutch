require 'hutch/logging'

module Hutch
  class CLI
    include Logging

    # Run a Hutch worker with the command line interface.
    def run
      parse_options

      Hutch.logger.info "hutch booted with pid #{Process.pid}"

      load_app
      start_work_loop

      # If we got here, the worker was shut down nicely
      Hutch.logger.info 'hutch shut down gracefully'
      exit 0
    end

    def load_app
      ENV['RACK_ENV'] ||= ENV['RAILS_ENV'] || 'development'
      rails_env_path = File.expand_path('config/environment.rb')
      if File.exists?(rails_env_path)
        logger.info 'found rails project, loading rails environment'
        require rails_env_path
        ::Rails.application.eager_load!
      end
    end

    # Kick off the work loop. This method returns when the worker is shut down
    # gracefully (with a SIGQUIT, SIGTERM or SIGINT).
    def start_work_loop
      @worker = Hutch::Worker.new(Hutch.consumers)
      # Set up signal handlers for graceful shutdown
      register_signal_handlers
      @worker.run
    end

    def parse_options
      parser = OptionParser.new do |opts|
        opts.banner = 'usage: hutch [options]'

        opts.on('--rabbitmq-host HOST', 'Set the RabbitMQ host') do |host|
          Hutch.config[:rabbitmq_host] = host
        end

        opts.on('--rabbitmq-port PORT', 'Set the RabbitMQ port') do |port|
          Hutch.config[:rabbitmq_port] = port
        end

        opts.on('--rabbitmq-exchange PORT',
                'Set the RabbitMQ exchange') do |exchange|
          Hutch.config[:rabbitmq_exchange] = exchange
        end

        opts.on('-q', '--quiet', 'Quiet logging') do
          Hutch.config[:log_level] = Logger::WARN
        end

        opts.on('-v', '--verbose', 'Verbose logging') do
          Hutch.config[:log_level] = Logger::DEBUG
        end

        opts.on('--version', 'Print the version and exit') do
          puts "hutch v#{VERSION}"
          exit 0
        end

        opts.on('-h', '--help', 'Show this message and exit') do
          puts opts
          exit 0
        end
      end.parse!
    end

    # Register handlers for SIG{QUIT,TERM,INT} to shut down the worker
    # gracefully. Forceful shutdowns are very bad!
    def register_signal_handlers
      %w(QUIT TERM INT).map(&:to_sym).each do |sig|
        trap(sig) do
          Hutch.logger.info "caught sig#{sig.downcase}, stopping hutch..."
          @worker.stop
        end
      end
    end
  end
end

