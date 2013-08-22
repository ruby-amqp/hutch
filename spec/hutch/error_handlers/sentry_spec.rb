require 'spec_helper'

describe Hutch::ErrorHandlers::Sentry do
  let(:error_handler) { Hutch::ErrorHandlers::Sentry.new }

  describe '#handle' do
    let(:error) do
      begin
        raise "Stuff went wrong"
      rescue RuntimeError => err
        err
      end
    end

    it "logs the error to Sentry" do
      Raven.should_receive(:capture_exception).with(error)
      error_handler.handle("1", stub, error)
    end
  end
end
