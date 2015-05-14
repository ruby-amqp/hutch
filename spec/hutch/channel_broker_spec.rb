require 'spec_helper'
require 'hutch/channel_broker'

describe Hutch::ChannelBroker do
  let(:config) { deep_copy(Hutch::Config.user_config) }
  let(:connection) { double('Connection') }
  let(:channel) { double('Channel') }
  subject(:channel_broker) { Hutch::ChannelBroker.new(connection, config) }

  shared_examples 'an empty channel broker' do
    %i(channel exchange default_wait_exchange wait_exchanges).each do |name|
      it { expect(channel_broker.instance_variable_get("@#{name}")).to be_nil }
    end
  end

  describe '#disconnect' do
    before do
      channel_broker.instance_variable_set('@channel', channel)
      allow(channel_broker).to receive(:active).and_return(active)
      allow(channel).to receive(:close)
    end

    subject! { channel_broker.disconnect }

    context 'when active' do
      let(:active) { true }

      it { expect(channel).to have_received(:close) }
      it_behaves_like 'an empty channel broker'
    end

    context 'when not active' do
      let(:active) { false }

      it { expect(channel).to_not have_received(:close) }
      it_behaves_like 'an empty channel broker'
    end
  end

  describe '#reconnect' do
    let(:new_channel) { double('Channel') }

    before do
      allow(channel_broker).to receive(:disconnect)
      allow(channel_broker).to receive(:open_channel!).and_return(new_channel)
    end

    subject! { channel_broker.reconnect }

    it { expect(channel_broker).to have_received(:disconnect) }
    it { expect(channel_broker).to have_received(:open_channel!) }
    it { is_expected.to eq(new_channel) }
  end

  describe '#active' do
    before do
      channel_broker.instance_variable_set('@channel', channel)
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
