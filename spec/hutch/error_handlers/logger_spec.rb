require 'spec_helper'

describe Hutch::ErrorHandlers::Logger do
  let(:error_handler) { Hutch::ErrorHandlers::Logger.new }

  describe '#handle' do
    let(:properties) { OpenStruct.new(message_id: "1") }
    let(:payload) { "{}" }
    let(:error) { double(message: "Stuff went wrong", class: "RuntimeError",
                       backtrace: ["line 1", "line 2"]) }

    it "logs three separate lines" do
      expect(Hutch::Logging.logger).to receive(:error).exactly(3).times
      error_handler.handle(properties, payload, double, error)
    end
  end

  describe '#handle_setup_exception' do
    let(:error) { double(message: "Stuff went wrong during setup",
                       class: "RuntimeError",
                       backtrace: ["line 1", "line 2"]) }

    it "logs two separate lines" do
      expect(Hutch::Logging.logger).to receive(:error).exactly(2).times
      error_handler.handle_setup_exception(error)
    end
  end
end
