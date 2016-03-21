require 'spec_helper'
require 'consumer_helper'
require 'hutch/setup/queues'

describe Hutch::Setup::Queues do
  include ConsumerFactory

  let(:broker) { instance_double("Hutch::Broker") }
  let(:consumers) { Array.new(2) { build_consumer } }
  subject(:setup_performer) { described_class.new(broker, consumers) }

  describe '#call' do
    it 'sets up queues for each of the consumers' do
      consumers.each do |consumer|
        queue = instance_double('Bunny::Queue')
        expect(broker).to receive(:queue)
          .with(consumer.get_queue_name, consumer.get_arguments)
          .and_return(queue)
        expect(broker).to receive(:bind_queue)
          .with(queue, consumer.routing_keys)

        prc = Proc.new {}
        expect(Hutch::Config[:message_preprocessing_proc])
          .to receive(:to_proc).and_return(prc)
        expect(queue).to receive(:subscribe).with(manual_ack: true) do |&blk|
          expect(blk).to eq(prc)
        end
      end

      setup_performer.call
    end
  end

  describe ".call" do
    it "delegates to #call with default arguments" do
      expect(described_class)
        .to receive(:new)
        .with(Hutch.broker, Hutch.consumers)
        .and_return(setup_performer)
      expect(setup_performer)
        .to receive(:call)

      described_class.call
    end
  end
end
