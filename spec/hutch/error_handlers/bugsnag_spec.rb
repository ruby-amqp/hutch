# frozen_string_literal: true

require "spec_helper"

describe Hutch::ErrorHandlers::Bugsnag do
  let(:error_handler) { described_class.new }

  before do
    Bugsnag.configure do |bugsnag|
      bugsnag.api_key = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      bugsnag.logger = Logger.new(File::NULL) # suppress logging
    end
  end

  describe "#handle" do
    let(:error) do
      begin
        raise "Stuff went wrong"
      rescue RuntimeError => err
        err
      end
    end

    it "logs the error to Bugsnag" do
      message_id = "1"
      properties = OpenStruct.new(message_id: message_id)
      payload = "{}"
      consumer = double
      ex = error
      message = {
        payload: payload,
        consumer: consumer
      }

      expect(::Bugsnag).to receive(:notify).with(ex).and_call_original
      expect_any_instance_of(::Bugsnag::Report).to receive(:add_tab).with(:hutch, message)
      error_handler.handle(properties, payload, consumer, ex)
    end
  end

  describe "#handle_setup_exception" do
    let(:error) do
      begin
        raise "Stuff went wrong"
      rescue RuntimeError => err
        err
      end
    end

    it "logs the error to Bugsnag" do
      ex = error
      expect(::Bugsnag).to receive(:notify).with(ex)
      error_handler.handle_setup_exception(ex)
    end
  end
end
