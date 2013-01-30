require 'spec_helper'
require 'hutch/broker'

describe Hutch::Broker do
  let(:config) { deep_copy(Hutch::Config.user_config) }
  subject(:broker) { Hutch::Broker.new(config) }

  describe 'set_up_amqp_connection', rabbitmq: true do
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

  describe 'set_up_api_connection', rabbitmq: true do
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
end

