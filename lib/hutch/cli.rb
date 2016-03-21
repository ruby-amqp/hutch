require 'optparse'

require 'hutch/version'
require 'hutch/logging'
require 'hutch/exceptions'
require 'hutch/config'

module Hutch
  class CLI
    include Logging

    # Run a Hutch worker with the command line interface.
    def run(argv = ARGV)
      parse_options(argv)

      ::Process.daemon(true) if Hutch::Config.daemonise

      write_pid if Hutch::Config.pidfile

      Hutch.logger.info "hutch booted with pid #{::Process.pid}"

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
      load_rails_app('.') if Hutch::Config.autoload_rails
      Hutch::Config.require_paths.each do |path|
        # See if each path is a Rails app. If so, try to load it.
        next if load_rails_app(path)

        # Given path is not a Rails app, try requiring it as a file
        logger.info "requiring '#{path}'"
        begin
          # Need to add '.' to load path for relative requires
          $LOAD_PATH << '.'
          require path
        rescue LoadError => e
          logger.fatal "could not load file '#{path}': #{e}"
          return false
        ensure
          # Clean up load path
          $LOAD_PATH.pop
        end
      end

      # Because of the order things are required when we run the Hutch binary
      # in hutch/bin, the Sentry Raven gem gets required **after** the error
      # handlers are set up. Due to this, we never got any Sentry notifications
      # when an error occurred in any of the consumers.
      if defined?(Raven)
        Hutch::Config[:error_handlers] << Hutch::ErrorHandlers::Sentry.new
      end

      true
    end

    def load_rails_app(path)
      # path should point to the app's top level directory
      if File.directory?(path)
        # Smells like a Rails app if it's got a script/rails or bin/rails file
        is_rails_app = ['script/rails', 'bin/rails'].any? do |file|
          File.exist?(File.expand_path(File.join(path, file)))
        end
        rails_path = File.expand_path(File.join(path, 'config/environment.rb'))
        if is_rails_app && File.exist?(rails_path)
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
      Hutch.connect
      @worker = Hutch::Worker.new(Hutch.broker, Hutch::Config[:setup_procs])
      @worker.run
      :success
    rescue ConnectionError, AuthenticationError, WorkerSetupError => ex
      logger.fatal ex.message
      :error
    end

    def parse_options(args = ARGV)
      OptionParser.new do |opts|
        opts.banner = 'usage: hutch [options]'

        opts.on('--mq-host HOST', 'Set the RabbitMQ host') do |host|
          Hutch::Config.mq_host = host
        end

        opts.on('--mq-port PORT', 'Set the RabbitMQ port') do |port|
          Hutch::Config.mq_port = port
        end

        opts.on("-t", "--[no-]mq-tls", 'Use TLS for the AMQP connection') do |tls|
          Hutch::Config.mq_tls = tls
        end

        opts.on('--mq-tls-cert FILE', 'Certificate  for TLS client verification') do |file|
          abort "Certificate file '#{file}' not found" unless File.exists?(file)
          Hutch::Config.mq_tls_cert = file
        end

        opts.on('--mq-tls-key FILE', 'Private key for TLS client verification') do |file|
          abort "Private key file '#{file}' not found" unless File.exists?(file)
          Hutch::Config.mq_tls_key = file
        end

        opts.on('--mq-exchange EXCHANGE',
                'Set the RabbitMQ exchange') do |exchange|
          Hutch::Config.mq_exchange = exchange
        end

        opts.on('--mq-vhost VHOST', 'Set the RabbitMQ vhost') do |vhost|
          Hutch::Config.mq_vhost = vhost
        end

        opts.on('--mq-username USERNAME',
                'Set the RabbitMQ username') do |username|
          Hutch::Config.mq_username = username
        end

        opts.on('--mq-password PASSWORD',
                'Set the RabbitMQ password') do |password|
          Hutch::Config.mq_password = password
        end

        opts.on('--mq-api-host HOST', 'Set the RabbitMQ API host') do |host|
          Hutch::Config.mq_api_host = host
        end

        opts.on('--mq-api-port PORT', 'Set the RabbitMQ API port') do |port|
          Hutch::Config.mq_api_port = port
        end

        opts.on("-s", "--[no-]mq-api-ssl", 'Use SSL for the RabbitMQ API') do |api_ssl|
          Hutch::Config.mq_api_ssl = api_ssl
        end

        opts.on('--config FILE', 'Load Hutch configuration from a file') do |file|
          begin
            File.open(file) { |fp| Hutch::Config.load_from_file(fp) }
          rescue Errno::ENOENT
            abort "Config file '#{file}' not found"
          end
        end

        opts.on('--require PATH', 'Require a Rails app or path') do |path|
          Hutch::Config.require_paths << path
        end

        opts.on('--[no-]autoload-rails', 'Require the current rails app directory') do |autoload_rails|
          Hutch::Config.autoload_rails = autoload_rails
        end

        opts.on('-q', '--quiet', 'Quiet logging') do
          Hutch::Config.log_level = Logger::WARN
        end

        opts.on('-v', '--verbose', 'Verbose logging') do
          Hutch::Config.log_level = Logger::DEBUG
        end

        opts.on('--namespace NAMESPACE', 'Queue namespace') do |namespace|
          Hutch::Config.namespace = namespace
        end

        opts.on('-d', '--daemonise', 'Daemonise') do |daemonise|
          Hutch::Config.daemonise = daemonise
        end

        opts.on('--pidfile PIDFILE', 'Pidfile') do |pidfile|
          Hutch::Config.pidfile = pidfile
        end

        opts.on('--version', 'Print the version and exit') do
          puts "hutch v#{VERSION}"
          exit 0
        end

        opts.on('-h', '--help', 'Show this message and exit') do
          puts opts
          exit 0
        end
      end.parse!(args)
    end

    def write_pid
      pidfile = File.expand_path(Hutch::Config.pidfile)
      Hutch.logger.info "writing pid in #{pidfile}"
      File.open(pidfile, 'w') { |f| f.puts ::Process.pid }
    end

  end
end
