require 'hutch/logging'

module Hutch
  class Waiter
    include Logging

    SHUTDOWN_SIGNALS = %w(QUIT TERM INT).keep_if { |s| Signal.list.keys.include? s }.freeze

    def self.wait_until_signaled
      new.wait_until_signaled
    end

    def wait_until_signaled
      self.sig_read, self.sig_write = IO.pipe

      register_signal_handlers
      wait_for_signal

      sig = sig_read.gets.strip.downcase
      logger.info "caught sig#{sig}, stopping hutch..."
    end

    private

    attr_accessor :sig_read, :sig_write

    def wait_for_signal
      IO.select([sig_read])
    end

    def register_signal_handlers
      SHUTDOWN_SIGNALS.each do |sig|
        # This needs to be reentrant, so we queue up signals to be handled
        # in the run loop, rather than acting on signals here
        trap(sig) do
          sig_write.puts(sig)
        end
      end
    end
  end
end
