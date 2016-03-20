require 'optparse'

require 'hutch/version'
require 'hutch/logging'
require 'hutch/exceptions'
require 'hutch/cli_config'

module Hutch
  class CLI
    include Logging
    include CLIConfig

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

    private

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
      @worker = Hutch::Worker.new(Hutch.broker, Hutch.consumers)
      @worker.run
      :success
    rescue ConnectionError, AuthenticationError, WorkerSetupError => ex
      logger.fatal ex.message
      :error
    end

    def parse_options(args = ARGV)
      OptionParser.new do |opts|
        opts.banner = 'usage: hutch [options]'

        opt_host(opts)
        opt_port(opts)
        opt_tls(opts)
        opt_cert_file(opts)
        opt_key_file(opts)
        opt_exchange(opts)
        opt_vhost(opts)
        opt_username(opts)
        opt_password(opts)
        opt_api_host(opts)
        opt_api_port(opts)
        opt_api_ssl(opts)
        opt_config_file(opts)
        opt_path(opts)
        opt_autoload_rails(opts)
        opt_quiet_logging(opts)
        opt_verbose_logging(opts)
        opt_namespace(opts)
        opt_daemonise(opts)
        opt_pidfile(opts)
        opt_print_version(opts)
        opt_print_help(opts)
      end.parse!(args)
    end

    def write_pid
      pidfile = File.expand_path(Hutch::Config.pidfile)
      Hutch.logger.info "writing pid in #{pidfile}"
      File.open(pidfile, 'w') { |f| f.puts ::Process.pid }
    end
  end
end
