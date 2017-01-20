require 'hutch/logging'

module Hutch
  # Signal-handling class.
  #
  # Currently, the signal USR2 performs a thread dump,
  # while QUIT, TERM and INT all perform a graceful shutdown.
  class Waiter
    include Logging

    class ContinueProcessingSignals < RuntimeError
    end

    def self.supported_signals_of(list)
      list.keep_if { |s| Signal.list.keys.include?(s) }.tap do |result|
        result.delete('QUIT') if defined?(JRUBY_VERSION)
      end
    end

    SHUTDOWN_SIGNALS = supported_signals_of(%w(QUIT TERM INT)).freeze
    # We have chosen a JRuby-supported signal
    USER_SIGNALS = supported_signals_of(%w(USR2)).freeze
    REGISTERED_SIGNALS = (SHUTDOWN_SIGNALS + USER_SIGNALS).freeze

    def self.wait_until_signaled
      new.wait_until_signaled
    end

    def wait_until_signaled
      self.sig_read, self.sig_write = IO.pipe

      register_signal_handlers

      begin
        wait_for_signal

        sig = sig_read.gets.strip
        handle_signal(sig)
      rescue ContinueProcessingSignals
        retry
      end
    end

    def handle_signal(sig)
      raise ContinueProcessingSignals unless REGISTERED_SIGNALS.include?(sig)
      if user_signal?(sig)
        handle_user_signal(sig)
      else
        handle_shutdown_signal(sig)
      end
    end

    # @raises ContinueProcessingSignals
    def handle_user_signal(sig)
      case sig
      when 'USR2' then log_thread_backtraces
      else raise "Assertion failed - unhandled signal: #{sig.inspect}"
      end
      raise ContinueProcessingSignals
    end

    def handle_shutdown_signal(sig)
      logger.info "caught SIG#{sig}, stopping hutch..."
    end

    private

    def log_thread_backtraces
      logger.info 'Requested a VM-wide thread stack trace dump...'
      Thread.list.each do |thread|
        logger.info "Thread TID-#{thread.object_id.to_s(36)} #{thread['label']}"
        logger.info backtrace_for(thread)
      end
    end

    def backtrace_for(thread)
      if thread.backtrace
        thread.backtrace.join("\n")
      else
        '<no backtrace available>'
      end
    end

    attr_accessor :sig_read, :sig_write

    def wait_for_signal
      IO.select([sig_read])
    end

    def register_signal_handlers
      REGISTERED_SIGNALS.each do |sig|
        # This needs to be reentrant, so we queue up signals to be handled
        # in the run loop, rather than acting on signals here
        trap(sig) do
          sig_write.puts(sig)
        end
      end
    end

    def user_signal?(sig)
      USER_SIGNALS.include?(sig)
    end
  end
end
