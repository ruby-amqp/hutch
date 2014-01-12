require 'spec_helper'

describe Hutch do
  describe '.register_consumer' do
    let(:consumer_a) { double('Consumer') }
    let(:consumer_b) { double('Consumer') }

    it 'saves the consumers in the global consumer list' do
      Hutch.register_consumer(consumer_a)
      Hutch.register_consumer(consumer_b)
      Hutch.consumers.should include consumer_a
      Hutch.consumers.should include consumer_b
    end
  end

  describe '.connect' do
    context 'not connected' do
      let(:options) { double 'options' }
      let(:config)  { double 'config' }
      let(:broker)  { double 'broker' }
      let(:action)  { Hutch.connect(options, config) }

      it 'passes options and config' do
        Hutch::Broker.should_receive(:new).with(config).and_return broker
        broker.should_receive(:connect).with options

        action
      end

      it 'sets @connect' do
        action

        expect(Hutch.connected?).to be_true
      end
    end

    context 'connected' do
      before { Hutch.stub(:connected?).and_return true }

      it 'does not reconnect' do
        Hutch::Broker.should_not_receive :new
        Hutch.connect
      end
    end
  end

  describe '#publish' do
    let(:broker) { double(Hutch::Broker) }
    let(:args) { ['test.key', 'message', { headers: { foo: 'bar' } }] }

    before do
      Hutch.stub broker: broker
    end

    it 'delegates to Hutch::Broker#publish' do
      broker.should_receive(:publish).with(*args)
      Hutch.publish(*args)
    end
  end
end

