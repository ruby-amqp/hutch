require 'hutch/waiter'

RSpec.describe Hutch::Waiter do
  describe '.wait_until_signaled' do
    let(:pid) { Process.pid }
    def start_kill_thread(signal)
      Thread.new do
        # sleep allows the worker time to set up the signal handling
        # before the kill signal is sent.
        sleep 0.001
        Process.kill signal, pid
      end
    end

    described_class::SHUTDOWN_SIGNALS.each do |signal|
      # JRuby does not support QUIT:
      # The signal QUIT is in use by the JVM and will not work correctly on this platform
      next if signal == 'QUIT' && defined?(JRUBY_VERSION)

      context "a #{signal} signal is received" do
        it "logs that hutch is stopping" do
          expect(Hutch::Logging.logger).to receive(:info)
            .with("caught SIG#{signal}, stopping hutch...")

          start_kill_thread(signal)
          described_class.wait_until_signaled
        end
      end
    end
  end

  describe described_class::SHUTDOWN_SIGNALS do
    it "includes only things in Signal.list.keys" do
      expect(described_class).to eq(described_class & Signal.list.keys)
    end
  end
end
