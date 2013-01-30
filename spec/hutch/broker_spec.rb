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
  end

  describe '#set_up_api_connection', rabbitmq: true do
    context 'with valid details' do
      before { broker.set_up_api_connection }
      after  { broker.disconnect }

      its(:api_client) { should be_a CarrotTop }
    end

    context 'when given invalid details' do
      before { config[:mq_host] = 'notarealhost' }
      after  { broker.disconnect }
      let(:set_up_api_connection) { ->{ broker.set_up_api_connection } }

      specify { set_up_api_connection.should raise_error }
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
end

