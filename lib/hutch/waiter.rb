require 'hutch/logging'

module Hutch
  class Waiter
    include Logging
    
    class SkipHere < Exception
    end
    
    SHUTDOWN_SIGNALS = %w(QUIT TERM INT).keep_if { |s| Signal.list.keys.include? s }.freeze
    USER_SIGNALS = %w(USR1 USR2).keep_if { |s| Signal.list.keys.include?(s) }.freeze

    def self.wait_until_signaled
      new.wait_until_signaled
    end

    def wait_until_signaled
      self.sig_read, self.sig_write = IO.pipe

      register_signal_handlers
      
      begin
        wait_for_signal

        sig = sig_read.gets.strip.downcase
        if USER_SIGNALS.include?(sig.upcase)
          logger.info "FUN TIME! #{sig}"
          raise SkipHere
        else
          logger.info "caught sig#{sig}, stopping hutch..."
        end
      rescue SkipHere
        retry
      end
    end

    private

    attr_accessor :sig_read, :sig_write

    def wait_for_signal
      IO.select([sig_read])
    end

    def register_signal_handlers
      (SHUTDOWN_SIGNALS + USER_SIGNALS).each do |sig|
        # This needs to be reentrant, so we queue up signals to be handled
        # in the run loop, rather than acting on signals here
        trap(sig) do
          sig_write.puts(sig)
        end
      end
    end
  end
end
