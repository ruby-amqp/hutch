require 'spec_helper'

describe Hutch do
  describe '.register_consumer' do
    let(:consumer_a) { double('Consumer') }
    let(:consumer_b) { double('Consumer') }

    it 'saves the consumers in the global consumer list' do
      Hutch.register_consumer(consumer_a)
      Hutch.register_consumer(consumer_b)
      Hutch.consumers.should include consumer_a
      Hutch.consumers.should include consumer_b
    end
  end
end

