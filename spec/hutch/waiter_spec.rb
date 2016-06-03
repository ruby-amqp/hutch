require 'hutch/waiter'

RSpec.describe Hutch::Waiter do
  describe '.wait_until_signaled' do
    def start_kill_thread(signal)
      Thread.new do
        # sleep allows the worker time to set up the signal handling
        # before the kill signal is sent.
        sleep 0.1
        Process.kill signal, 0
      end
    end

    %w(QUIT TERM INT).each do |signal|
      context "a #{signal} signal is received" do
        it "logs that hutch is stopping" do
          expect(Hutch::Logging.logger).to receive(:info)
            .with("caught sig#{signal.downcase}, stopping hutch...")

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
