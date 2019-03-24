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

    context 'a QUIT signal is received', if: RSpec::Support::Ruby.mri? do
      it 'logs that hutch is stopping' do
        expect(Hutch::Logging.logger).to receive(:info)
          .with('caught SIGQUIT, stopping hutch...')

        start_kill_thread('QUIT')
        described_class.wait_until_signaled
      end
    end

    context 'a TERM signal is received', if: !defined?(JRUBY_VERSION) do
      it 'logs that hutch is stopping' do
        expect(Hutch::Logging.logger).to receive(:info)
          .with('caught SIGTERM, stopping hutch...')

        start_kill_thread('TERM')
        described_class.wait_until_signaled
      end
    end

    context 'a INT signal is received', if: !defined?(JRUBY_VERSION) do
      it 'logs that hutch is stopping' do
        expect(Hutch::Logging.logger).to receive(:info)
          .with('caught SIGINT, stopping hutch...')

        start_kill_thread('INT')
        described_class.wait_until_signaled
      end
    end
  end

  describe described_class::SHUTDOWN_SIGNALS do
    it 'includes only things in Signal.list.keys' do
      expect(described_class).to eq(described_class & Signal.list.keys)
    end
  end
end
