require 'spec_helper'

describe Hutch::ErrorHandlers::Logger do
  describe '#handle' do
    let(:error) { stub(message: "Stuff went wrong", class: "RuntimeError",
                       backtrace: ["line 1", "line 2"]) }
    subject { described_class.new.handle("1", stub, error) }

    it "logs three separate lines to stdout" do
      Hutch::Logging.logger.should_receive(:warn).exactly(3).times
      subject
    end
  end
end
