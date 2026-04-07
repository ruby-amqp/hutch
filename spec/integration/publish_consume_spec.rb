require 'spec_helper'
require 'hutch/broker'
require 'hutch/worker'
require 'hutch/consumer'
require 'securerandom'
require 'timeout'

describe 'publishing and consuming messages', rabbitmq: true, adapter: :bunny do
  let(:exchange_name) { "hutch.test.#{SecureRandom.hex(4)}" }
  let(:routing_key) { "test.message" }
  let(:received) { [] }

  let(:consumer_class) do
    msgs = received
    rk = routing_key
    qn = "test_consumer_#{SecureRandom.hex(4)}"

    Class.new do
      include Hutch::Consumer
      consume rk
      queue_name qn

      define_method(:process) { |message| msgs << message.body }
    end
  end

  let(:broker) { Hutch::Broker.new }
  let(:worker) { Hutch::Worker.new(broker, [consumer_class], []) }

  before do
    Hutch::Config.set(:mq_exchange, exchange_name)
  end

  after do
    broker.disconnect rescue nil
  end

  it 'publishes and consumes a message' do
    broker.connect
    worker.setup_queues

    broker.publish(routing_key, { test: 'data' })

    Timeout.timeout(5) { sleep 0.1 until received.any? }

    expect(received.first).to eq('test' => 'data')
  end
end
