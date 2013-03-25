require 'spec_helper'

describe Hutch::ErrorHandlers::Logger do
  describe '#handle' do
    let(:error) { stub(message: "Stuff went wrong", class: "RuntimeError",
                       backtrace: ["line 1", "line 2"]) }

    context "with the default logger" do
      subject { described_class.new.handle("1", stub, error) }

      it "logs three separate lines to stdout" do
        Hutch::Logging.logger.should_receive(:warn).exactly(3).times
        subject
      end
    end

    context "with the default logger" do
      let(:rails_stub) { Object.new }
      before { rails_stub.stub(:logger).and_return(stub(warn: true)) }
      subject { described_class.new(Rails.logger).handle("1", stub, error) }

      it "logs three separate lines to stdout" do
        stub_const("Rails", rails_stub)
        Rails.logger.should_receive(:warn).exactly(3).times
        subject
      end
    end
  end
end
