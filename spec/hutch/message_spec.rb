require 'hutch/message'

describe Hutch::Message do
  let(:delivery_info) { double('Delivery Info') }
  let(:props) { double('Properties', content_type: "application/json") }
  let(:body) {{ foo: 'bar' }.with_indifferent_access}
  let(:json_body) { MultiJson.dump(body) }
  subject(:message) { Hutch::Message.new(delivery_info, props, json_body, Hutch::Config[:serializer]) }

  describe '#body' do
    subject { super().body }
    it { is_expected.to eq(body) }
  end

  describe '[]' do
    subject { message[:foo] }
    it { is_expected.to eq('bar') }
  end

  [:message_id, :timestamp].each do |method|
    describe method.to_s do
      it 'delegates to @properties' do
        expect(props).to receive(method)
        message.send(method)
      end
    end
  end

  [:routing_key, :exchange].each do |method|
    describe method.to_s do
      it 'delegates to @delivery_info' do
        expect(delivery_info).to receive(method)
        message.send(method)
      end
    end
  end
end
