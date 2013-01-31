require 'hutch/logging'

module Hutch
  class CLI
    include Logging

    # Run a Hutch worker with the command line interface.
    def run
      parse_options

      Hutch.logger.info "hutch booted with pid #{Process.pid}"

      if load_app && start_work_loop == :success
        # If we got here, the worker was shut down nicely
        Hutch.logger.info 'hutch shut down gracefully'
        exit 0
      else
        Hutch.logger.info 'hutch terminated due to an error'
        exit 1
      end
    end

    def load_app
      # Try to load a Rails app in the current directory
      load_rails_app('.')
      Hutch::Config.require_paths.each do |path|
        # See if each path is a Rails app. If so, try to load it.
        next if load_rails_app(path)

        # Given path is not a Rails app, try requiring it as a file
        logger.info "requiring '#{path}'"
        begin
          # Need to add '.' to load path for relative requires
          $LOAD_PATH << '.'
          require path
        rescue LoadError => ex
          logger.fatal "could not load file '#{path}'"
          return false
        ensure
          # Clean up load path
          $LOAD_PATH.pop
        end
      end
      true
    end

    def load_rails_app(path)
      # path should point to the app's top level directory
      if File.directory?(path)
        # Smells like a Rails app if it's got a config/environment.rb file
        rails_path = File.expand_path(File.join(path, 'config/environment.rb'))
        if File.exists?(rails_path)
          logger.info "found rails project (#{path}), booting app"
          ENV['RACK_ENV'] ||= ENV['RAILS_ENV'] || 'development'
          require rails_path
          ::Rails.application.eager_load!
          return true
        end
      end
      false
    end

    # Kick off the work loop. This method returns when the worker is shut down
    # gracefully (with a SIGQUIT, SIGTERM or SIGINT).
    def start_work_loop
      broker = Hutch::Broker.new
      broker.connect
      @worker = Hutch::Worker.new(broker, Hutch.consumers)
      # Set up signal handlers for graceful shutdown
      register_signal_handlers
      @worker.run
    end

    def parse_options
      parser = OptionParser.new do |opts|
        opts.banner = 'usage: hutch [options]'

        opts.on('--mq-host HOST', 'Set the RabbitMQ host') do |host|
          Hutch::Config.mq_host = host
        end

        opts.on('--mq-port PORT', 'Set the RabbitMQ port') do |port|
          Hutch::Config.mq_port = port
        end

        opts.on('--mq-exchange PORT', 'Set the RabbitMQ exchange') do |exchange|
          Hutch::Config.mq_exchange = exchange
        end

        # TODO: options for rabbit api config

        opts.on('--require PATH', 'Require a Rails app or path') do |path|
          Hutch::Config.require_paths << path
        end

        opts.on('-q', '--quiet', 'Quiet logging') do
          Hutch::Config.log_level = Logger::WARN
        end

        opts.on('-v', '--verbose', 'Verbose logging') do
          Hutch::Config.log_level = Logger::DEBUG
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

