require 'hutch/message'
require 'hutch/logging'
require 'hutch/broker'
require 'hutch/acknowledgements/nack_on_all_failures'
require 'carrot-top'

module Hutch
  class Worker
    include Logging

    SHUTDOWN_SIGNALS = %w(QUIT TERM INT)

    def initialize(broker, setup_procs)
      @broker          = broker
      self.setup_procs = setup_procs
    end

    # Run the main event loop. The consumers will be set up with queues, and
    # process the messages in their respective queues indefinitely. This method
    # never returns.
    def run
      setup_procs.each(&:call)

      # Set up signal handlers for graceful shutdown
      register_signal_handlers

      main_loop
    end

    def main_loop
      if defined?(JRUBY_VERSION)
        # Binds shutdown listener to notify main thread if channel was closed
        bind_shutdown_handler

        handle_signals until shutdown_not_called?(0.1)
      else
        # Take a break from Thread#join every 0.1 seconds to check if we've
        # been sent any signals
        handle_signals until @broker.wait_on_threads(0.1)
      end
    end

    # Register handlers for SIG{QUIT,TERM,INT} to shut down the worker
    # gracefully. Forceful shutdowns are very bad!
    def register_signal_handlers
      Thread.main[:signal_queue] = []
      supported_shutdown_signals.each do |sig|
        # This needs to be reentrant, so we queue up signals to be handled
        # in the run loop, rather than acting on signals here
        trap(sig) do
          Thread.main[:signal_queue] << sig
        end
      end
    end

    # Handle any pending signals
    def handle_signals
      signal = Thread.main[:signal_queue].shift
      if signal
        logger.info "caught sig#{signal.downcase}, stopping hutch..."
        stop
      end
    end

    # Stop a running worker by killing all subscriber threads.
    def stop
      @broker.stop
    end

    # Binds shutdown handler, called if channel is closed or network Failed
    def bind_shutdown_handler
      @broker.channel.on_shutdown do
        Thread.main[:shutdown_received] = true
      end
    end

    # Checks if shutdown handler was called, then sleeps for interval
    def shutdown_not_called?(interval)
      if Thread.main[:shutdown_received]
        true
      else
        sleep(interval)
        false
      end
    end

    private

    def supported_shutdown_signals
      SHUTDOWN_SIGNALS.keep_if { |s| Signal.list.keys.include? s }.map(&:to_sym)
    end
  end
end
