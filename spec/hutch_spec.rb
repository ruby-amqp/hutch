require 'spec_helper'

describe Hutch do
  describe '.register_consumer' do
    let(:consumer_a) { double('Consumer') }
    let(:consumer_b) { double('Consumer') }

    it 'saves the consumers in the global consumer list' do
      Hutch.register_consumer(consumer_a)
      Hutch.register_consumer(consumer_b)
      expect(Hutch.consumers).to include consumer_a
      expect(Hutch.consumers).to include consumer_b
    end
  end

  describe '.connect' do
    context 'not connected' do
      let(:options) { double 'options' }
      let(:config)  { double 'config' }
      let(:broker)  { double 'broker' }
      let(:action)  { Hutch.connect(options, config) }

      it 'passes options and config' do
        expect(Hutch::Broker).to receive(:new).with(config).and_return broker
        expect(broker).to receive(:connect).with options

        action
      end

      it 'sets @connect' do
        action

        expect(Hutch.connected?).to be_truthy
      end
    end

    context 'connected' do
      before { allow(Hutch).to receive(:connected?).and_return true }

      it 'does not reconnect' do
        expect(Hutch::Broker).not_to receive :new
        Hutch.connect
      end
    end
  end

  describe '#publish' do
    subject { Hutch.publish(*args) }

    let(:broker) { double(Hutch::Broker) }
    let(:args) { ['test.key', 'message', { headers: { foo: 'bar' } }] }

    before do
      allow(Hutch).to receive(:broker).and_return(broker)
      allow(Hutch).to receive(:connect)
      allow(broker).to receive(:publish)
    end

    context "when connection is initiated" do
      before { allow(Hutch).to receive(:connected?).and_return true }

      it "doesn't initiate connection again" do
        subject
        expect(Hutch).not_to have_received(:connect)
      end

      it 'delegates to Hutch::Broker#publish' do
        subject
        expect(broker).to have_received(:publish).with(*args)
      end
    end

    context "when connection isn't initiated" do
      before { allow(Hutch).to receive(:connected?).and_return false }

      it "initiates connection" do
        subject
        expect(Hutch).to have_received(:connect).ordered
      end

      it 'delegates to Hutch::Broker#publish' do
        subject
        expect(broker).to have_received(:publish).with(*args).ordered
      end
    end

  end
end

