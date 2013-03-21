require 'spec_helper'

describe Hutch::ErrorBackends::Sentry do
  describe '#handle' do
    let(:error) { stub(message: "Stuff went wrong", class: "RuntimeError",
                       backtrace: ["line 1", "line 2"]) }
    let(:event) { stub }
    subject { described_class.new.handle("1", stub, error) }

    specify do
      Raven::Event.should_receive(:capture_exception).with(error).
                   and_return(event)
      Raven.should_receive(:send).with(event)
      subject
    end
  end
end
