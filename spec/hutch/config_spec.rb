require 'hutch/config'

describe Hutch::Config do
  let(:new_value) { 'not-localhost' }

  describe '.get' do
    context 'for valid attributes' do
      subject { Hutch::Config.get(:mq_host) }

      context 'with no overridden value' do
        it { should == 'localhost' }
      end

      context 'with an overridden value' do
        before  { Hutch::Config.stub(user_config: { mq_host: new_value }) }
        it { should == new_value }
      end
    end

    context 'for invalid attributes' do
      let(:invalid_get) { ->{ Hutch::Config.get(:invalid_attr) } }
      specify { invalid_get.should raise_error Hutch::UnknownAttributeError }
    end
  end

  describe '.set' do
    context 'for valid attributes' do
      before  { Hutch::Config.set(:mq_host, new_value) }
      subject { Hutch::Config.user_config[:mq_host] }

      context 'sets value in user config hash' do
        it { should == new_value }
      end
    end

    context 'for invalid attributes' do
      let(:invalid_set) { ->{ Hutch::Config.set(:invalid_attr, new_value) } }
      specify { invalid_set.should raise_error Hutch::UnknownAttributeError }
    end
  end

  describe 'a magic getter' do
    context 'for a valid attribute' do
      it 'calls get' do
        Hutch::Config.should_receive(:get).with(:mq_host)
        Hutch::Config.mq_host
      end
    end

    context 'for an invalid attribute' do
      let(:invalid_getter) { ->{ Hutch::Config.invalid_attr } }
      specify { invalid_getter.should raise_error NoMethodError }
    end
  end

  describe 'a magic setter' do
    context 'for a valid attribute' do
      it 'calls set' do
        Hutch::Config.should_receive(:set).with(:mq_host, new_value)
        Hutch::Config.mq_host = new_value
      end
    end

    context 'for an invalid attribute' do
      let(:invalid_setter) { ->{ Hutch::Config.invalid_attr = new_value } }
      specify { invalid_setter.should raise_error NoMethodError }
    end
  end
end
