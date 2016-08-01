require 'spec_helper'

describe Hutch::ErrorHandlers::Sentry do
  let(:error_handler) { Hutch::ErrorHandlers::Sentry.new }

  describe '#handle' do
    let(:properties) { OpenStruct.new(message_id: "1") }
    let(:payload) { "{}" }
    let(:error) do
      begin
        raise "Stuff went wrong"
      rescue RuntimeError => err
        err
      end
    end

    it "logs the error to Sentry" do
      expect(Raven).to receive(:capture_exception).with(error, extra: { payload: payload })
      error_handler.handle(properties, payload, double, error)
    end
  end
end
