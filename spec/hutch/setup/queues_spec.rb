require 'spec_helper'
require 'factory_helper'
require 'hutch/setup/queues'

describe Hutch::Setup::Queues do
  let(:broker) { instance_double("Hutch::Broker") }
  let(:consumers) { Array.new(2) { build_consumer } }
  subject(:setup_performer) { described_class.new(broker, consumers) }

  describe '#call' do
    it 'sets up queues for each of the consumers' do
      consumers.each do |consumer|
        queue = build_queue
        expect(broker).to receive(:queue)
          .with(consumer.get_queue_name, consumer.get_arguments)
          .and_return(queue)
        expect(broker).to receive(:bind_queue)
          .with(queue, consumer.routing_keys)
        expect(queue).to receive(:subscribe).with(manual_ack: true)
      end

      setup_performer.call
    end
  end
end
