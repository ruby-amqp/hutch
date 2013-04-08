require 'spec_helper'

describe Hutch::Logging do
  let(:dummy_object) do
    class DummyObject
      include Hutch::Logging
    end
  end

  describe '#logger' do
    context 'with the default logger' do
      subject { Hutch::Logging.logger }

      it { should be_instance_of(Logger) }
    end

    context 'with a custom logger' do
      let(:dummy_logger) { mock("Dummy logger", warn: true, info: true) }
      after { Hutch::Logging.setup_logger }

      it "users the custom logger" do
        Hutch::Logging.logger = dummy_logger
        Hutch::Logging.logger.should == dummy_logger
      end
    end
  end
end

