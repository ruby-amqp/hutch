require 'spec_helper'
require 'hutch/channel_broker'

describe Hutch::ChannelBroker do
  let(:channel) { double('Channel') }
  subject(:channel_broker) { Hutch::ChannelBroker.new(channel) }

  describe 'attributes' do
    it { is_expected.to respond_to(:channel) }
    it { is_expected.to respond_to(:channel=) }
    it { is_expected.to respond_to(:exchange) }
    it { is_expected.to respond_to(:exchange=) }
    it { is_expected.to respond_to(:default_wait_exchange) }
    it { is_expected.to respond_to(:default_wait_exchange=) }
    it { is_expected.to respond_to(:wait_exchanges) }
    it { is_expected.to respond_to(:wait_exchanges=) }
  end

  describe '#reconnect' do
    let(:new_channel) { double('Channel') }

    before do
      allow(channel_broker).to receive(:disconnect)
    end

    subject! { channel_broker.reconnect(new_channel) }

    it { expect(channel_broker).to have_received(:disconnect) }
    it { expect(channel_broker.channel).to eq(new_channel) }
  end

  describe '#disconnect' do
    before do
      allow(channel).to receive(:active).and_return(active)
      allow(channel).to receive(:close)
    end

    subject! { channel_broker.disconnect }

    context 'when channel is active' do
      let(:active) { true }

      it { expect(channel).to have_received(:close) }
      it { expect(channel_broker.channel).to be_nil }
      it { expect(channel_broker.exchange).to be_nil }
      it { expect(channel_broker.default_wait_exchange).to be_nil }
      it { expect(channel_broker.wait_exchanges).to be_empty }
    end

    context 'when channel is not active' do
      let(:active) { false }

      it { expect(channel).to_not have_received(:close) }
      it { expect(channel_broker.channel).to be_nil }
      it { expect(channel_broker.exchange).to be_nil }
      it { expect(channel_broker.default_wait_exchange).to be_nil }
      it { expect(channel_broker.wait_exchanges).to be_empty }
    end
  end

  describe '#active' do
    before do
      allow(channel).to receive(:active).and_return(active)
    end

    subject { channel_broker.active }

    context 'when channel is active' do
      let(:active) { true }

      it { is_expected.to be true }
    end

    context 'when channel is not active' do
      let(:active) { false }

      it { is_expected.to be_falsey }
    end

    context 'when channel is nil' do
      let(:channel) { nil }
      let(:active) { true }

      it { is_expected.to be_falsey }
    end
  end
end
