require 'spec_helper'

describe Hutch::ErrorHandlers::Rollbar do
  let(:error_handler) { Hutch::ErrorHandlers::Rollbar.new }

  describe '#handle' do
    let(:error) do
      begin
        raise "Stuff went wrong"
      rescue RuntimeError => err
        err
      end
    end

    it "logs the error to Rollbar" do
      message_id = "1"
      properties = OpenStruct.new(message_id: message_id)
      payload = "{}"
      consumer = double
      ex = error
      message = {
        payload: payload,
        consumer: consumer
      }
      expect(::Rollbar).to receive(:error).with(ex, message)
      error_handler.handle(properties, payload, consumer, ex)
    end
  end

  describe '#handle_setup_exception' do
    let(:error) do
      begin
        raise "Stuff went wrong"
      rescue RuntimeError => err
        err
      end
    end

    it "logs the error to Rollbar" do
      ex = error
      expect(::Rollbar).to receive(:error).with(ex)
      error_handler.handle_setup_exception(ex)
    end
  end
end
