require 'spec_helper'

describe Hutch::Logging do
  let(:dummy_object) do
    class DummyObject
      include described_class
    end
  end

  describe '#logger' do
    around do |example|
      old_logger = described_class.logger
      described_class.setup_logger
      example.run
      described_class.logger = old_logger
    end

    context 'with the default logger' do
      subject { described_class.logger }

      it { is_expected.to be_instance_of(Logger) }
    end

    context 'with a custom logger' do
      let(:dummy_logger) { double("Dummy logger") }

      it "users the custom logger" do
        described_class.logger = dummy_logger
        expect(described_class.logger).to eq(dummy_logger)
      end
    end
  end
end

