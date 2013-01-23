require 'hutch/message'

describe Message do
  let(:metadata) { double('Metadata') }
  let(:body) {{ foo: 'bar' }}
  subject(:message) { Message.new(metadata, MultiJson.dump(body)) }

  its(:body) { should == body }

  describe '[]' do
    subject { message[:foo] }
    it { should == 'bar' }
  end

  [:routing_key, :timestamp, :exchange].each do |method|
    describe method.to_s do
      it 'delegates to @metadata' do
        metadata.should_receive(method)
        message.send(method)
      end
    end
  end
end

