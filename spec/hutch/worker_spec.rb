require 'spec_helper'
require 'hutch/worker'

describe Hutch::Worker do
  before { Raven.as_null_object }
  let(:consumer) { double('Consumer', routing_keys: %w( a b c ),
                          get_queue_name: 'consumer') }
  let(:consumers) { [consumer, double('Consumer')] }
  let(:broker) { Hutch::Broker.new }
  subject(:worker) { Hutch::Worker.new(broker, consumers) }

  describe '#setup_queues' do
    it 'sets up queues for each of the consumers' do
      consumers.each do |consumer|
        worker.should_receive(:setup_queue).with(consumer)
      end
      worker.setup_queues
    end
  end

  describe '#setup_queue' do
    let(:queue) { double('Queue', bind: nil, subscribe: nil) }
    before { worker.stub(consumer_queue: queue) }
    before { broker.stub(queue: queue, bind_queue: nil) }

    it 'creates a queue' do
      broker.should_receive(:queue).with(consumer.get_queue_name).and_return(queue)
      worker.setup_queue(consumer)
    end

    it 'binds the queue to each of the routing keys' do
      broker.should_receive(:bind_queue).with(queue, %w( a b c ))
      worker.setup_queue(consumer)
    end

    it 'sets up a subscription' do
      queue.should_receive(:subscribe).with(ack: true)
      worker.setup_queue(consumer)
    end
  end

  describe '#handle_message' do
    let(:payload) { '{}' }
    let(:consumer_instance) { double('Consumer instance') }
    let(:delivery_info) { double('Delivery Info', routing_key: '',
                                 delivery_tag: 'dt') }
    let(:properties) { double('Properties', message_id: nil) }
    before { consumer.stub(new: consumer_instance) }
    before { broker.stub(:ack) }
    before { broker.stub(:nack) }

    it 'passes the message to the consumer' do
      consumer_instance.should_receive(:process).
                        with(an_instance_of(Hutch::Message))
      worker.handle_message(consumer, delivery_info, properties, payload)
    end

    it 'acknowledges the message' do
      consumer_instance.stub(:process)
      broker.should_receive(:ack).with(delivery_info.delivery_tag)
      worker.handle_message(consumer, delivery_info, properties, payload)
    end

    context 'when the consumer raises an exception' do
      before { consumer_instance.stub(:process).and_raise('a consumer error') }

      it 'logs the error' do
        Hutch::Config[:error_handlers].each do |backend|
          backend.should_receive(:handle)
        end
        worker.handle_message(consumer, delivery_info, properties, payload)
      end

      it 'rejects the message' do
        broker.should_receive(:nack).with(delivery_info.delivery_tag)
        worker.handle_message(consumer, delivery_info, properties, payload)
      end
    end

    context "when the payload is not valid json" do
      let(:payload) { "Not Valid JSON" }

      it 'logs the error' do
        Hutch::Config[:error_handlers].each do |backend|
          backend.should_receive(:handle)
        end
        worker.handle_message(consumer, delivery_info, properties, payload)
      end

      it 'rejects the message' do
        broker.should_receive(:nack).with(delivery_info.delivery_tag)
        worker.handle_message(consumer, delivery_info, properties, payload)
      end
    end
  end
end

