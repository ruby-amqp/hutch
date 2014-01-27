require 'spec_helper'
require 'hutch/broker'

describe Hutch::Broker do
  let(:config) { deep_copy(Hutch::Config.user_config) }
  subject(:broker) { Hutch::Broker.new(config) }

  describe '#connect' do
    before { broker.stub(:set_up_amqp_connection) }
    before { broker.stub(:set_up_api_connection) }
    before { broker.stub(:disconnect) }

    it 'sets up the amqp connection' do
      broker.should_receive(:set_up_amqp_connection)
      broker.connect
    end

    it 'sets up the api connection' do
      broker.should_receive(:set_up_api_connection)
      broker.connect
    end

    it 'does not disconnect' do
      broker.should_not_receive(:disconnect)
      broker.connect
    end

    context 'when given a block' do
      it 'disconnects' do
        broker.should_receive(:disconnect).once
        broker.connect { }
      end
    end

    context "with options" do
      let(:options) { { enable_http_api_use: false } }

      it "doesnt set up api" do
        broker.should_not_receive(:set_up_api_connection)
        broker.connect options
      end
    end
  end

  describe '#set_up_amqp_connection', rabbitmq: true do
    context 'with valid details' do
      before { broker.set_up_amqp_connection }
      after  { broker.disconnect }

      its(:connection) { should be_a Bunny::Session }
      its(:channel)    { should be_a Bunny::Channel }
      its(:exchange)   { should be_a Bunny::Exchange }
    end

    context 'when given invalid details' do
      before { config[:mq_host] = 'notarealhost' }
      let(:set_up_amqp_connection) { ->{ broker.set_up_amqp_connection } }

      specify { set_up_amqp_connection.should raise_error }
    end

    context 'with channel_prefetch set' do
      let(:prefetch_value) { 1 }
      before { config[:channel_prefetch] = prefetch_value }
      after  { broker.disconnect }

      it "set's channel's prefetch" do
        Bunny::Channel.any_instance.should_receive(:prefetch).with(prefetch_value)
        broker.set_up_amqp_connection
      end
    end
  end

  describe '#set_up_api_connection', rabbitmq: true do
    context 'with valid details' do
      before { broker.set_up_api_connection }
      after  { broker.disconnect }

      its(:api_client) { should be_a CarrotTop }
    end

    context 'when given invalid details' do
      before { config[:mq_api_host] = 'notarealhost' }
      after  { broker.disconnect }
      let(:set_up_api_connection) { ->{ broker.set_up_api_connection } }

      specify { set_up_api_connection.should raise_error }
    end
  end

  describe '#queue' do
    let(:channel) { double('Channel') }
    before { broker.stub(:channel) { channel } }

    it 'applies a global namespace' do
      config[:namespace] = 'mirror-all.service'
      broker.channel.should_receive(:queue).with { |*args| args.first == 'mirror-all.service:test' }
      broker.queue('test')
    end
  end

  describe '#bindings', rabbitmq: true do
    around { |example| broker.connect { example.run } }
    subject { broker.bindings }

    context 'with no bindings' do
      its(:keys) { should_not include 'test' }
    end

    context 'with a binding' do
      around do |example|
        queue = broker.queue('test').bind(broker.exchange, routing_key: 'key')
        example.run
        queue.unbind(broker.exchange, routing_key: 'key').delete
      end

      it { should include({ 'test' => ['key'] }) }
    end
  end

  describe '#bind_queue' do

    around { |example| broker.connect { example.run } }

    let(:routing_keys) { %w( a b c ) }
    let(:queue) { double('Queue', bind: nil, unbind: nil, name: 'consumer') }
    before { broker.stub(bindings: { 'consumer' => ['d'] }) }

    it 'calls bind for each routing key' do
      routing_keys.each do |key|
        queue.should_receive(:bind).with(broker.exchange, routing_key: key)
      end
      broker.bind_queue(queue, routing_keys)
    end

    it 'calls unbind for each redundant existing binding' do
      queue.should_receive(:unbind).with(broker.exchange, routing_key: 'd')
      broker.bind_queue(queue, routing_keys)
    end

    context '(rabbitmq integration test)', rabbitmq: true do
      let(:queue) { broker.queue('consumer') }
      let(:routing_key) { 'key' }

      before { broker.unstub(:bindings) }
      before { queue.bind(broker.exchange, routing_key: 'redundant-key') }
      after { queue.unbind(broker.exchange, routing_key: routing_key).delete }

      it 'results in the correct bindings' do
        broker.bind_queue(queue, [routing_key])
        broker.bindings.should include({ queue.name => [routing_key] })
      end
    end
  end

  describe '#wait_on_threads' do
    let(:thread) { double('Thread') }
    before { broker.stub(work_pool_threads: threads) }

    context 'when all threads finish within the timeout' do
      let(:threads) { [double(join: thread), double(join: thread)] }
      specify { expect(broker.wait_on_threads(1)).to be_true }
    end

    context 'when timeout expires for one thread' do
      let(:threads) { [double(join: thread), double(join: nil)] }
      specify { expect(broker.wait_on_threads(1)).to be_false }
    end
  end

  describe '#publish' do
    context 'with a valid connection' do
      before { broker.set_up_amqp_connection }
      after  { broker.disconnect }

      it 'publishes to the exchange' do
        broker.exchange.should_receive(:publish).once
        broker.publish('test.key', 'message')
      end

      it 'sets default properties' do
        broker.exchange.should_receive(:publish).with(
          JSON.dump("message"),
          hash_including(
            persistent: true,
            routing_key: 'test.key',
            content_type: 'application/json'
          )
        )

        broker.publish('test.key', 'message')
      end

      it 'allows passing message properties' do
        broker.exchange.should_receive(:publish).once
        broker.publish('test.key', 'message', {expiration: "2000", persistent: false})
      end

      context 'when there are global properties' do
        context 'as a hash' do
          before do
            Hutch.stub global_properties: { app_id: 'app' }
          end

          it 'merges the properties' do
            broker.exchange.should_receive(:publish).with('"message"', hash_including(app_id: 'app'))
            broker.publish('test.key', 'message')
          end
        end

        context 'as a callable object' do
          before do
            Hutch.stub global_properties: proc { { app_id: 'app' } }
          end

          it 'calls the proc and merges the properties' do
            broker.exchange.should_receive(:publish).with('"message"', hash_including(app_id: 'app'))
            broker.publish('test.key', 'message')
          end
        end
      end
    end

    context 'without a valid connection' do
      it 'raises an exception' do
        expect { broker.publish('test.key', 'message') }.
          to raise_exception(Hutch::PublishError)
      end

      it 'logs an error' do
        broker.logger.should_receive(:error)
        broker.publish('test.key', 'message') rescue nil
      end
    end
  end
end

