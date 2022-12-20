require 'spec_helper'

describe Hutch::ErrorHandlers::SentryRaven do
  let(:error_handler) { Hutch::ErrorHandlers::SentryRaven.new }

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
      expect(Raven).to receive(:capture_exception).with(error, {extra: { payload: payload }})
      error_handler.handle(properties, payload, double, error)
    end
  end

  describe '#handle_setup_exception' do
    let(:error) do
      begin
        raise "Stuff went wrong during setup"
      rescue RuntimeError => err
        err
      end
    end

    it "logs the error to Sentry" do
      expect(Raven).to receive(:capture_exception).with(error)
      error_handler.handle_setup_exception(error)
    end
  end
end
