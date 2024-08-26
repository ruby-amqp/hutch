require 'spec_helper'
require 'hutch/worker'

describe Hutch::Worker do
  let(:consumer) { double('Consumer', routing_keys: %w( a b c ),
                          get_queue_name: 'consumer', get_arguments: {},
                          get_options: {}, get_serializer: nil) }
  let(:consumers) { [consumer, double('Consumer')] }
  let(:broker) { Hutch::Broker.new }
  let(:setup_procs) { Array.new(2) { Proc.new {} } }
  subject(:worker) { Hutch::Worker.new(broker, consumers, setup_procs) }

  describe ".#run" do
    it "calls each setup proc" do
      setup_procs.each { |prc| expect(prc).to receive(:call) }
      allow(worker).to receive(:setup_queues)
      allow(Hutch::Waiter).to receive(:wait_until_signaled)
      allow(broker).to receive(:stop)

      worker.run
    end
  end

  describe '#setup_queues' do
    it 'sets up queues for each of the consumers' do
      consumers.each do |consumer|
        expect(worker).to receive(:setup_queue).with(consumer)
      end
      worker.setup_queues
    end
  end

  describe '#setup_queue' do
    let(:queue) { double('Queue', bind: nil, subscribe: nil) }
    before { allow(broker).to receive_messages(queue: queue, bind_queue: nil) }

    it 'creates a queue' do
      expect(broker).to receive(:queue).with(consumer.get_queue_name, consumer.get_options).and_return(queue)
      worker.setup_queue(consumer)
    end

    it 'binds the queue to each of the routing keys' do
      expect(broker).to receive(:bind_queue).with(queue, %w( a b c ))
      worker.setup_queue(consumer)
    end

    it 'sets up a subscription' do
      expect(queue).to receive(:subscribe).with(consumer_tag: %r(^hutch\-.{36}$), manual_ack: true)
      worker.setup_queue(consumer)
    end

    context 'with a configured consumer tag prefix' do
      before { Hutch::Config.set(:consumer_tag_prefix, 'appname') }

      it 'sets up a subscription with the configured tag prefix' do
        expect(queue).to receive(:subscribe).with(consumer_tag: %r(^appname\-.{36}$), manual_ack: true)
        worker.setup_queue(consumer)
      end
    end

    context 'with a configured consumer tag prefix that is too long' do
      let(:maximum_size) { 255 - SecureRandom.uuid.size - 1 }
      before { Hutch::Config.set(:consumer_tag_prefix, 'a'.*(maximum_size + 1)) }

      it 'raises an error' do
        expect { worker.setup_queue(consumer) }.to raise_error(/Tag must be 255 bytes long at most/)
      end
    end
  end

  describe '#handle_message' do
    subject { worker.handle_message(consumer, delivery_info, properties, payload) }
    let(:payload) { '{}' }
    let(:consumer_instance) { double('Consumer instance') }
    let(:delivery_info) { double('Delivery Info', routing_key: '',
                                 delivery_tag: 'dt') }
    let(:properties) { double('Properties', message_id: nil, content_type: "application/json") }
    let(:log) { StringIO.new }
    before { allow(consumer).to receive_messages(new: consumer_instance) }
    before { allow(broker).to receive(:ack) }
    before { allow(broker).to receive(:nack) }
    before { allow(consumer_instance).to receive(:broker=) }
    before { allow(consumer_instance).to receive(:delivery_info=) }
    before { allow(Hutch::Logging).to receive(:logger).and_return(Logger.new(log)) }

    it 'passes the message to the consumer' do
      expect(consumer_instance).to receive(:process).
                        with(an_instance_of(Hutch::Message))
      expect(consumer_instance).to receive(:message_rejected?).and_return(false)
      subject
    end

    it 'acknowledges the message' do
      allow(consumer_instance).to receive(:process)
      expect(broker).to receive(:ack).with(delivery_info.delivery_tag)
      expect(consumer_instance).to receive(:message_rejected?).and_return(false)
      subject
    end

    context 'when the consumer fails and a requeue is configured' do

      it 'requeues the message' do
        allow(consumer_instance).to receive(:process).and_raise('failed')
        requeuer = double
        allow(requeuer).to receive(:handle) { |delivery_info, properties, broker, e|
          broker.requeue delivery_info.delivery_tag
          true
        }
        allow(worker).to receive(:error_acknowledgements).and_return([requeuer])
        expect(broker).to_not receive(:ack)
        expect(broker).to_not receive(:nack)
        expect(broker).to receive(:requeue)

        subject
      end
    end


    context 'when the consumer raises an exception' do
      let(:expected_log) { /ERROR .+ error in consumer .+ RuntimeError .+ backtrace:/m }
      before { allow(consumer_instance).to receive(:process).and_raise('a consumer error') }

      it 'logs the error' do
        expect { subject }.to change { log.tap(&:rewind).read }.from("").to(expected_log)
      end

      it 'rejects the message' do
        expect(broker).to receive(:nack).with(delivery_info.delivery_tag)
        subject
      end

      context 'when a custom error handler supports delivery info' do
        let(:error_handler) do
          Class.new(Hutch::ErrorHandlers::Base) do
            def handle(_properties, _payload, _consumer, _ex, delivery_info)
              raise unless delivery_info.delivery_tag == 'dt'
              puts 'handled!'
            end
          end
        end

        around do |example|
          original = Hutch::Config[:error_handlers]
          Hutch::Config[:error_handlers] = [error_handler.new]
          example.run
          Hutch::Config[:error_handlers] = original
        end

        it 'calls the custom handler with delivery info' do
          expect { subject }.to output("handled!\n").to_stdout
        end
      end

      context 'when a custom error handler does not support delivery info' do
        let(:error_handler) do
          Class.new(Hutch::ErrorHandlers::Base) do
            def handle(_properties, _payload, _consumer, _ex)
              puts 'handled!'
            end
          end
        end

        around do |example|
          original = Hutch::Config[:error_handlers]
          Hutch::Config[:error_handlers] = [error_handler.new]
          example.run
          Hutch::Config[:error_handlers] = original
        end

        it 'calls the custom handler with delivery info' do
          expect { subject }.to output("handled!\n").to_stdout
        end
      end
    end

    context "when the payload is not valid json" do
      let(:payload) { "Not Valid JSON" }
      let(:expected_log) { /ERROR .+ error in consumer .+ MultiJson::ParseError .+ backtrace:/m }

      it 'logs the error' do
        expect { subject }.to change { log.tap(&:rewind).read }.from("").to(expected_log)
      end

      it 'rejects the message' do
        expect(broker).to receive(:nack).with(delivery_info.delivery_tag)
        subject
      end
    end
  end


  describe '#acknowledge_error' do
    let(:delivery_info) { double('Delivery Info', routing_key: '',
                                 delivery_tag: 'dt') }
    let(:properties) { double('Properties', message_id: 'abc123') }

    subject { worker.acknowledge_error delivery_info, properties, broker, StandardError.new }

    it 'stops when it runs a successful acknowledgement' do
      skip_ack = double handle: false
      always_ack = double handle: true
      never_used = double handle: true

      allow(worker).
        to receive(:error_acknowledgements).
        and_return([skip_ack, always_ack, never_used])

      expect(never_used).to_not receive(:handle)

      subject
    end

    it 'defaults to nacking' do
      skip_ack = double handle: false

      allow(worker).
        to receive(:error_acknowledgements).
        and_return([skip_ack, skip_ack])

      expect(broker).to receive(:nack)

      subject
    end
  end
end

