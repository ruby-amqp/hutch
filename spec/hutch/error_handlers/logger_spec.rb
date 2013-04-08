require 'spec_helper'

describe Hutch::ErrorHandlers::Logger do
  let(:error_handler) { Hutch::ErrorHandlers::Logger.new }

  describe '#handle' do
    let(:error) { stub(message: "Stuff went wrong", class: "RuntimeError",
                       backtrace: ["line 1", "line 2"]) }

    it "logs three separate lines" do
      Hutch::Logging.logger.should_receive(:error).exactly(3).times
      error_handler.handle("1", stub, error)
    end
  end
end
