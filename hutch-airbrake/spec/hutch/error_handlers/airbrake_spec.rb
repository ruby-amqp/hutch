require 'spec_helper'

describe Hutch::ErrorHandlers::Airbrake do
  let(:error_handler) { Hutch::ErrorHandlers::Airbrake.new }

  describe '#handle' do
    let(:error) do
      begin
        raise "Stuff went wrong"
      rescue RuntimeError => err
        err
      end
    end

    it "logs the error to Airbrake" do
      message_id = "1"
      payload = "{}"
      consumer = double
      ex = error
      message = {
        :error_class => ex.class.name,
        :error_message => "#{ ex.class.name }: #{ ex.message }",
        :backtrace => ex.backtrace,
        :parameters => {
          :payload => payload,
          :consumer => consumer,
        },
        :cgi_data => ENV.to_hash,
      }
      expect(::Airbrake).to receive(:notify_or_ignore).with(ex, message)
      error_handler.handle(message_id, payload, consumer, ex)
    end
  end
end
