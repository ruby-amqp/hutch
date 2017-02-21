require 'spec_helper'

describe Hutch::ErrorHandlers::Honeybadger do
  let(:error_handler) { Hutch::ErrorHandlers::Honeybadger.new }

  describe '#handle' do
    let(:error) do
      begin
        raise "Stuff went wrong"
      rescue RuntimeError => err
        err
      end
    end

    it "logs the error to Honeybadger" do
      message_id = "1"
      properties = OpenStruct.new(message_id: message_id)
      payload = "{}"
      consumer = double
      ex = error
      message = {
        :error_class => ex.class.name,
          :error_message => "#{ ex.class.name }: #{ ex.message }",
          :backtrace => ex.backtrace,
          :context => {
            :message_id => message_id,
            :consumer => consumer
          },
          :parameters => {
            :payload => payload
          }
      }
      expect(error_handler).to receive(:notify_honeybadger).with(message)
      error_handler.handle(properties, payload, consumer, ex)
    end
  end
end
