require 'spec_helper'

describe Hutch::ErrorHandlers::Sentry do
  let(:error_handler) { Hutch::ErrorHandlers::Sentry.new }

  describe '#handle' do
    let(:error) { stub(message: "Stuff went wrong", class: "RuntimeError",
                       backtrace: ["line 1", "line 2"]) }
    let(:event) { stub }

    it "logs the error to Sentry" do
      Raven::Event.should_receive(:capture_exception).with(error).
                   and_return(event)
      Raven.should_receive(:send).with(event)
      error_handler.handle("1", stub, error)
    end
  end
end
