require 'hutch/worker'

describe Hutch::Worker do
  let(:consumer) { double('Consumer', routing_keys: %w( a b c )) }
  let(:consumers) { [consumer, double('Consumer')] }
  subject(:worker) { Hutch::Worker.new(consumers) }

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

    it 'binds the queue to each of the routing keys' do
      %w( a b c ).each do |key|
        queue.should_receive(:bind).with(anything, routing_key: key)
      end
      worker.setup_queue(consumer)
    end

    it 'sets up a subscription' do
      queue.should_receive(:subscribe)
      worker.setup_queue(consumer)
    end
  end

  describe '#handle_message' do
    let(:payload) { '{}' }
    let(:consumer_instance) { double('Consumer instance') }
    it 'passes the message to the consumer' do
      consumer_instance.should_receive(:process).with(an_instance_of(Message))
      consumer.stub(new: consumer_instance)
      worker.handle_message(consumer, nil, payload)
    end
  end
end

