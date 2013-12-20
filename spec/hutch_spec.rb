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

