require 'hutch/logging'

module Hutch
  # Signal-handling class.
  class Waiter
    include Logging

    class ContinueProcessingSignals < RuntimeError
    end

    def self.supported_signals_of(list)
      list.keep_if { |s| Signal.list.keys.include? s }
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

    def handle_shutdown_signal(sig)
      logger.info "caught SIG#{sig}, stopping hutch..."
    end

    # @raises ContinueProcessingSignals
    def handle_user_signal(sig)
      case sig
      when 'USR2' then handle_usr2
      else raise "Assertion failed - unhandled signal: #{sig.inspect}"
      end
      raise ContinueProcessingSignals
    end

    private

    def handle_usr2
      Thread.list.each do |thread|
        logger.warn "Thread TID-#{thread.object_id.to_s(36)} #{thread['label']}"
        if thread.backtrace
          logger.warn thread.backtrace.join("\n")
        else
          logger.warn '<no backtrace available>'
        end
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
