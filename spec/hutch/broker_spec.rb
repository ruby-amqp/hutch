require 'spec_helper'
require 'hutch/broker'

describe Hutch::Broker do
  before do
    Hutch::Config.initialize(client_logger: Hutch::Logging.logger)
    @config = Hutch::Config.to_hash
  end
  let!(:config) { @config }
  after do
    Hutch::Config.instance_variable_set(:@config, nil)
    Hutch::Config.initialize
  end
  let(:broker) { Hutch::Broker.new(config) }

  describe '#connect' do
    before { allow(broker).to receive(:set_up_amqp_connection) }
    before { allow(broker).to receive(:set_up_api_connection) }
    before { allow(broker).to receive(:disconnect) }

    it 'sets up the amqp connection' do
      expect(broker).to receive(:set_up_amqp_connection)
      broker.connect
    end

    it 'sets up the api connection' do
      expect(broker).to receive(:set_up_api_connection)
      broker.connect
    end

    it 'does not disconnect' do
      expect(broker).not_to receive(:disconnect)
      broker.connect
    end

    context 'when given a block' do
      it 'disconnects' do
        expect(broker).to receive(:disconnect).once
        broker.connect { }
      end
    end

    context 'when given a block that fails' do
      let(:exception) { Class.new(StandardError) }

      it 'disconnects' do
        expect(broker).to receive(:disconnect).once
        expect do
          broker.connect { fail exception }
        end.to raise_error(exception)
      end
    end

    context "with options" do
      let(:options) { { enable_http_api_use: false } }

      it "doesnt set up api" do
        expect(broker).not_to receive(:set_up_api_connection)
        broker.connect options
      end
    end
  end

  describe '#set_up_amqp_connection' do
    it 'opens a connection, channel and declares an exchange' do
      expect(broker).to receive(:open_connection!).ordered
      expect(broker).to receive(:open_channel!).ordered
      expect(broker).to receive(:declare_exchange!).ordered

      broker.set_up_amqp_connection
    end
  end

  describe '#open_connection', rabbitmq: true do
    describe 'return value' do
      subject { broker.open_connection }
      after { subject.close }

      it(nil, adapter: :bunny)      { is_expected.to be_a Hutch::Adapters::BunnyAdapter }
      it(nil, adapter: :march_hare) { is_expected.to be_a Hutch::Adapters::MarchHareAdapter }
    end

    context 'when given invalid details' do
      before { config[:mq_host] = 'notarealhost' }
      it { expect { broker.open_connection }.to raise_error(StandardError) }
    end

    it 'does not set #connection' do
      connection = broker.open_connection

      expect(broker.connection).to be_nil

      connection.close
    end

    context 'when configured with a URI' do
      context 'which specifies the port' do
        before { config[:uri] = 'amqp://guest:guest@127.0.0.1:5672/' }

        it 'successfully connects' do
          c = broker.open_connection
          expect(c).to be_open
          c.close
        end
      end

      context 'which does not specify port and uses the amqp scheme' do
        before { config[:uri] = 'amqp://guest:guest@127.0.0.1/' }

        it 'successfully connects' do
          c = broker.open_connection
          expect(c).to be_open
          c.close
        end
      end

      context 'which specifies the amqps scheme' do
        before { config[:uri] = 'amqps://guest:guest@127.0.0.1/' }

        it 'utilises TLS' do
          expect(Hutch::Adapter).to receive(:new).with(
            hash_including(tls: true, port: 5671)
          ).and_return(instance_double('Hutch::Adapter', start: nil))

          broker.open_connection
        end
      end
    end
  end

  describe '#open_connection!' do
    it 'sets the #connection to #open_connection' do
      connection = double('connection').as_null_object

      expect(broker).to receive(:open_connection).and_return(connection)

      broker.open_connection!

      expect(broker.connection).to eq(connection)
    end
  end

  describe '#open_channel', rabbitmq: true do
    before { broker.open_connection! }
    after { broker.disconnect }

    describe 'return value' do
      subject { broker.open_channel }

      it(nil, adapter: :bunny)      { is_expected.to be_a Bunny::Channel }
      it(nil, adapter: :march_hare) { is_expected.to be_a MarchHare::Channel }
    end

    it 'does not set #channel' do
      broker.open_channel
      expect(broker.channel).to be_nil
    end

    context 'with channel_prefetch set' do
      let(:prefetch_value) { 1 }
      before { config[:channel_prefetch] = prefetch_value }

      it "set's channel's prefetch", adapter: :bunny do
        expect_any_instance_of(Bunny::Channel).to receive(:prefetch).with(prefetch_value)
        broker.open_channel
      end

      it "set's channel's prefetch", adapter: :march_hare do
        expect_any_instance_of(MarchHare::Channel).to receive(:prefetch=).with(prefetch_value)
        broker.open_channel
      end
    end

    context 'with force_publisher_confirms set' do
      let(:force_publisher_confirms_value) { true }
      before { config[:force_publisher_confirms] = force_publisher_confirms_value }

      it 'waits for confirmation', adapter: :bunny do
        expect_any_instance_of(Bunny::Channel).to receive(:confirm_select)
        broker.open_channel
      end

      it 'waits for confirmation', adapter: :march_hare do
        expect_any_instance_of(MarchHare::Channel).to receive(:confirm_select)
        broker.open_channel
      end
    end
  end

  describe '#open_channel!' do
    it 'sets the #channel to #open_channel' do
      channel = double('channel').as_null_object

      expect(broker).to receive(:open_channel).and_return(channel)

      broker.open_channel!

      expect(broker.channel).to eq(channel)
    end
  end

  describe '#declare_exchange' do
    before do
      broker.open_connection!
      broker.open_channel!
    end
    after { broker.disconnect }

    describe 'return value' do
      subject { broker.declare_exchange }

      it(nil, adapter: :bunny)      { is_expected.to be_a Bunny::Exchange }
      it(nil, adapter: :march_hare) { is_expected.to be_a MarchHare::Exchange }
    end

    it 'does not set #exchange' do
      broker.declare_exchange
      expect(broker.exchange).to be_nil
    end
  end

  describe '#declare_exchange!' do
    it 'sets the #exchange to #declare_exchange' do
      exchange = double('exchange').as_null_object

      expect(broker).to receive(:declare_exchange).and_return(exchange)

      broker.declare_exchange!

      expect(broker.exchange).to eq(exchange)
    end
  end

  describe '#set_up_api_connection', rabbitmq: true do
    context 'with valid details' do
      before { broker.set_up_api_connection }
      after  { broker.disconnect }

      describe '#api_client' do
        subject { broker.api_client }
        it { is_expected.to be_a CarrotTop }
      end
    end

    context 'when given invalid details' do
      before { config[:mq_api_host] = 'notarealhost' }
      after  { broker.disconnect }
      let(:set_up_api_connection) { broker.set_up_api_connection }

      specify { expect { broker.set_up_api_connection }.to raise_error(StandardError) }
    end
  end

  describe '#queue' do
    let(:channel) { double('Channel') }
    let(:arguments) { { foo: :bar } }
    before { allow(broker).to receive(:channel) { channel } }

    it 'applies a global namespace' do
      config[:namespace] = 'mirror-all.service'
      expect(broker.channel).to receive(:queue) do |*args|
        args.first == ''
        args.last == arguments
      end
      broker.queue('test', arguments: arguments)
    end
  end

  describe '#bindings', rabbitmq: true do
    around { |example| broker.connect { example.run } }
    subject { broker.bindings }

    context 'with no bindings' do
      describe '#keys' do
        subject { super().keys }
        it { is_expected.not_to include 'test' }
      end
    end

    context 'with a binding' do
      around do |example|
        queue = broker.queue('test').bind(broker.exchange, routing_key: 'key')
        example.run
        queue.unbind(broker.exchange, routing_key: 'key').delete
      end

      it { is_expected.to include({ 'test' => ['key'] }) }
    end
  end

  describe '#bind_queue' do

    around { |example| broker.connect(host: "127.0.0.1") { example.run } }

    let(:routing_keys) { %w( a b c ) }
    let(:queue) { double('Queue', bind: nil, unbind: nil, name: 'consumer') }
    before { allow(broker).to receive(:bindings).and_return('consumer' => ['d']) }

    it 'calls bind for each routing key' do
      routing_keys.each do |key|
        expect(queue).to receive(:bind).with(broker.exchange, routing_key: key)
      end
      broker.bind_queue(queue, routing_keys)
    end

    it 'calls unbind for each redundant existing binding' do
      expect(queue).to receive(:unbind).with(broker.exchange, routing_key: 'd')
      broker.bind_queue(queue, routing_keys)
    end

    context '(rabbitmq integration test)', rabbitmq: true do
      let(:queue) { broker.queue('consumer') }
      let(:routing_key) { 'key' }

      before { allow(broker).to receive(:bindings).and_call_original }
      before { queue.bind(broker.exchange, routing_key: 'redundant-key') }
      after { queue.unbind(broker.exchange, routing_key: routing_key).delete }

      it 'results in the correct bindings' do
        broker.bind_queue(queue, [routing_key])
        expect(broker.bindings).to include({ queue.name => [routing_key] })
      end
    end
  end

  describe '#stop', adapter: :bunny do
    let(:thread_1) { double('Thread') }
    let(:thread_2) { double('Thread') }
    let(:work_pool) { double('Bunny::ConsumerWorkPool') }
    let(:config) { { graceful_exit_timeout: 2 } }

    before do
      allow(broker).to receive(:channel_work_pool).and_return(work_pool)
    end

    it 'gracefully stops the work pool' do
      expect(work_pool).to receive(:shutdown)
      expect(work_pool).to receive(:join).with(2)
      expect(work_pool).to receive(:kill)

      broker.stop
    end
  end

  describe '#stop', adapter: :march_hare do
    let(:channel) { double('MarchHare::Channel')}

    before do
      allow(broker).to receive(:channel).and_return(channel)
    end

    it 'gracefully stops the channel' do
      expect(channel).to receive(:close)

      broker.stop
    end
  end

  describe '#publish' do
    context 'with a valid connection' do
      before { broker.set_up_amqp_connection }
      after  { broker.disconnect }

      it 'publishes to the exchange' do
        expect(broker.exchange).to receive(:publish).once
        broker.publish('test.key', {key: "value"})
      end

      it 'sets default properties' do
        expect(broker.exchange).to receive(:publish).with(
          JSON.dump({key: "value"}),
          hash_including(
            persistent: true,
            routing_key: 'test.key',
            content_type: 'application/json'
          )
        )

        broker.publish('test.key', {key: "value"})
      end

      it 'allows passing message properties' do
        expect(broker.exchange).to receive(:publish).once
        broker.publish('test.key', {key: "value"}, {expiration: "2000", persistent: false})
      end

      context 'when there are global properties' do
        context 'as a hash' do
          before do
            allow(Hutch).to receive(:global_properties).and_return(app_id: 'app')
          end

          it 'merges the properties' do
            expect(broker.exchange).
              to receive(:publish).with('{"key":"value"}', hash_including(app_id: 'app'))
            broker.publish('test.key', {key: "value"})
          end
        end

        context 'as a callable object' do
          before do
            allow(Hutch).to receive(:global_properties).and_return(proc { { app_id: 'app' } })
          end

          it 'calls the proc and merges the properties' do
            expect(broker.exchange).
              to receive(:publish).with('{"key":"value"}', hash_including(app_id: 'app'))
            broker.publish('test.key', {key: "value"})
          end
        end
      end

      context 'with force_publisher_confirms not set in the config' do
        it 'does not wait for confirms on the channel', adapter: :bunny do
          expect_any_instance_of(Bunny::Channel).
            to_not receive(:wait_for_confirms)
          broker.publish('test.key', {key: "value"})
        end

        it 'does not wait for confirms on the channel', adapter: :march_hare do
          expect_any_instance_of(MarchHare::Channel).
            to_not receive(:wait_for_confirms)
          broker.publish('test.key', {key: "value"})
        end
      end

      context 'with force_publisher_confirms set in the config' do
        let(:force_publisher_confirms_value) { true }

        before do
          config[:force_publisher_confirms] = force_publisher_confirms_value
        end

        it 'waits for confirms on the channel', adapter: :bunny do
          expect_any_instance_of(Bunny::Channel).
            to receive(:wait_for_confirms)
          broker.publish('test.key', {key: "value"})
        end

        it 'waits for confirms on the channel', adapter: :march_hare do
          expect_any_instance_of(MarchHare::Channel).
            to receive(:wait_for_confirms)
          broker.publish('test.key', {key: "value"})
        end
      end
    end

    context 'without a valid connection' do
      before { broker.set_up_amqp_connection; broker.disconnect }

      it 'raises an exception' do
        expect { broker.publish('test.key', {key: "value"}) }.
          to raise_exception(Hutch::PublishError)
      end

      it 'logs an error' do
        expect(broker.logger).to receive(:error)
        broker.publish('test.key', {key: "value"}) rescue nil
      end
    end
  end
end
