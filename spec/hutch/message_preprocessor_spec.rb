require 'spec_helper'
require 'consumer_helper'
require 'hutch/message_preprocessor'

describe Hutch::MessagePreprocessor do
  include ConsumerFactory

  subject(:handler) { described_class.new(broker, consumer, args) }
  let(:broker) { Hutch::Broker.new }
  let(:consumer) { build_consumer }
  let(:args) { [double.as_null_object, double.as_null_object, double.as_null_object] }
  let(:payload) { '{}' }
  let(:delivery_info) { double('Delivery Info', routing_key: '',
                               delivery_tag: 'dt') }
  let(:properties) { double('Properties', message_id: nil, content_type: "application/json") }

  before do
    allow(Hutch::Adapter)
      .to receive(:decode_message)
      .with(*args)
      .and_return([delivery_info, properties, payload])
  end

  describe '#call' do
    let(:consumer_instance) { double('Consumer instance') }

    before { allow(consumer).to receive(:new).and_return(consumer_instance) }
    before { allow(broker).to receive(:ack) }
    before { allow(broker).to receive(:nack) }
    before { allow(consumer_instance).to receive(:broker=) }
    before { allow(consumer_instance).to receive(:delivery_info=) }

    it 'passes the message to the consumer' do
      expect(consumer_instance).to receive(:process).
        with(an_instance_of(Hutch::Message))
      handler.call
    end

    it 'acknowledges the message' do
      allow(consumer_instance).to receive(:process)
      expect(broker).to receive(:ack).with(delivery_info.delivery_tag)
      handler.call
    end

    context 'when the consumer fails and a requeue is configured' do

      it 'requeues the message' do
        allow(consumer_instance).to receive(:process).and_raise('failed')
        requeuer = double
        allow(requeuer).to receive(:handle).ordered { |delivery_info, properties, broker, e|
          broker.requeue delivery_info.delivery_tag
          true
        }
        allow(handler).to receive(:error_acknowledgements).and_return([requeuer])
        expect(broker).to_not receive(:ack)
        expect(broker).to_not receive(:nack)
        expect(broker).to receive(:requeue)

        handler.call
      end
    end


    context 'when the consumer raises an exception' do
      before { allow(consumer_instance).to receive(:process).and_raise('a consumer error') }

      it 'logs the error' do
        Hutch::Config[:error_handlers].each do |backend|
          expect(backend).to receive(:handle)
        end
        handler.call
      end

      it 'rejects the message' do
        expect(broker).to receive(:nack).with(delivery_info.delivery_tag)
        handler.call
      end

      it 'stops when it runs a successful acknowledgement' do
        skip_ack = double handle: false
        always_ack = double handle: true
        never_used = double handle: true

        allow(handler).
          to receive(:error_acknowledgements).
          and_return([skip_ack, always_ack, never_used])

        expect(never_used).to_not receive(:handle)
        handler.call
      end

      it 'defaults to nacking' do
        expect(broker).to receive(:nack)

        handler.call
      end
    end

    context "when the payload is not valid json" do
      let(:payload) { "Not Valid JSON" }

      it 'logs the error' do
        Hutch::Config[:error_handlers].each do |backend|
          expect(backend).to receive(:handle)
        end
        handler.call
      end

      it 'rejects the message' do
        expect(broker).to receive(:nack).with(delivery_info.delivery_tag)
        handler.call
      end
    end
  end

  describe ".to_proc" do
    it "returns a proc that initializes and calls a consumer" do
      expect(Hutch).to receive(:broker).and_return(broker)
      expect(described_class)
        .to receive(:new)
        .with(broker, consumer, args)
        .and_return(handler)
      expect(handler).to receive(:call)

      described_class.to_proc(consumer).call(*args)
    end
  end
end
