require 'hutch/message'
require 'hutch/serializers/identity'
require 'hutch/tracers'

RSpec.describe Hutch::Tracers::Opbeat do
  let(:consumer) { double('the-consumer') }

  subject(:tracer) { described_class.new(consumer) }

  let(:message) do
    Hutch::Message.new(double('the-delivery-info', routing_key: 'foo.bar',
                                                   exchange: 'foo'),
                       double('the-properties', message_id: 'the-id',
                                                timestamp: 'the-time'),
                       double('the-payload', to_s: 'the-body'),
                       Hutch::Serializers::Identity)
  end

  it 'formats messages as extra information' do
    expected_extra = {
      body: 'the-body',
      message_id: 'the-id',
      timestamp: 'the-time',
      routing_key: 'foo.bar'
    }
    expect(Opbeat).to receive(:transaction).with(anything,
                                           'messaging.hutch',
                                           extra: expected_extra) {
                                             double('done-callback', done: true)
                                           }

    tracer.handle(message)
  end

  it 'presents consumer class name as Opbeat tracing signature' do
    expect(Opbeat).to receive(:transaction).with(consumer.class.name,
                                           'messaging.hutch',
                                           anything) {
                                             double('done-callback', done: true)
                                           }

    tracer.handle(message)
  end
end
