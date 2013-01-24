require 'hutch/logging'

module Hutch
  class CLI
    include Logging

    # Run a Hutch worker with the command line interface.
    def run
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

