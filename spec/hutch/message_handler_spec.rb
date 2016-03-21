require 'spec_helper'
require 'factory_helper'
require 'hutch/message_handler'

describe Hutch::MessageHandler do
  let(:broker) { instance_double("Hutch::Broker") }
  subject(:handler) { described_class.new(broker) }

  describe '#call' do
    let(:payload) { '{}' }
    let(:consumer_instance) { double('Consumer instance') }
    let(:delivery_info) { double('Delivery Info', routing_key: '',
                                 delivery_tag: 'dt') }
    let(:properties) { double('Properties', message_id: nil, content_type: "application/json") }
    let(:consumer) { build_consumer }

    before { allow(consumer).to receive(:new).and_return(consumer_instance) }
    before { allow(broker).to receive(:ack) }
    before { allow(broker).to receive(:nack) }
    before { allow(consumer_instance).to receive(:broker=) }
    before { allow(consumer_instance).to receive(:delivery_info=) }

    it 'passes the message to the consumer' do
      expect(consumer_instance).to receive(:process).
        with(an_instance_of(Hutch::Message))
      handler.call(consumer, delivery_info, properties, payload)
    end

    it 'acknowledges the message' do
      allow(consumer_instance).to receive(:process)
      expect(broker).to receive(:ack).with(delivery_info.delivery_tag)
      handler.call(consumer, delivery_info, properties, payload)
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

        handler.call(consumer, delivery_info, properties, payload)
      end
    end


    context 'when the consumer raises an exception' do
      before { allow(consumer_instance).to receive(:process).and_raise('a consumer error') }

      it 'logs the error' do
        Hutch::Config[:error_handlers].each do |backend|
          expect(backend).to receive(:handle)
        end
        handler.call(consumer, delivery_info, properties, payload)
      end

      it 'rejects the message' do
        expect(broker).to receive(:nack).with(delivery_info.delivery_tag)
        handler.call(consumer, delivery_info, properties, payload)
      end
    end

    context "when the payload is not valid json" do
      let(:payload) { "Not Valid JSON" }

      it 'logs the error' do
        Hutch::Config[:error_handlers].each do |backend|
          expect(backend).to receive(:handle)
        end
        handler.call(consumer, delivery_info, properties, payload)
      end

      it 'rejects the message' do
        expect(broker).to receive(:nack).with(delivery_info.delivery_tag)
        handler.call(consumer, delivery_info, properties, payload)
      end
    end
  end


  describe '#acknowledge_error' do
    let(:delivery_info) { double('Delivery Info', routing_key: '',
                                 delivery_tag: 'dt') }
    let(:properties) { double('Properties', message_id: 'abc123') }

    subject { handler.acknowledge_error delivery_info, properties, broker, StandardError.new }

    it 'stops when it runs a successful acknowledgement' do
      skip_ack = double handle: false
      always_ack = double handle: true
      never_used = double handle: true

      allow(handler).
        to receive(:error_acknowledgements).
        and_return([skip_ack, always_ack, never_used])

      expect(never_used).to_not receive(:handle)

      subject
    end

    it 'defaults to nacking' do
      skip_ack = double handle: false

      allow(handler).
        to receive(:error_acknowledgements).
        and_return([skip_ack, skip_ack])

      expect(broker).to receive(:nack)

      subject
    end
  end
end
