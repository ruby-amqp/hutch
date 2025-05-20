require 'spec_helper'

describe Hutch::ErrorHandlers::Sentry do
  let(:error_handler) { Hutch::ErrorHandlers::Sentry.new }

  before do
    Sentry.init do
      # initialize Sentry so that the integration acutally works
      # otherwise, all its methods are going to return early
      # so it will be impossible to check if it actually works
    end
  end

  describe '#handle' do
    let(:properties) { Struct.new(:message_id).new("1") }
    let(:payload) { "{}" }
    let(:error) do
      begin
        raise "Stuff went wrong"
      rescue RuntimeError => err
        err
      end
    end

    it "logs the error to Sentry" do
      expect(::Sentry).to receive(:capture_exception).with(error).and_call_original

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
      expect(::Sentry).to receive(:capture_exception).with(error).and_call_original

      error_handler.handle_setup_exception(error)
    end
  end
end
