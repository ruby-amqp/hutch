require 'spec_helper'

describe Hutch::Consumer do
  around(:each) do |example|
    isolate_constants do
      example.run
    end
  end

  let(:simple_consumer) do
    unless defined? SimpleConsumer
      class SimpleConsumer
        include Hutch::Consumer
        consume 'hutch.test1'
      end
    end
    SimpleConsumer
  end

  let(:complex_consumer) do
    unless defined? ComplexConsumer
      class ComplexConsumer
        include Hutch::Consumer
        consume 'hutch.test1', 'hutch.test2'
      end
    end
    ComplexConsumer
  end

  describe 'module inclusion' do
    it 'registers the class as a consumer' do
      Hutch.should_receive(:register_consumer) do |klass|
        klass.should == simple_consumer
      end

      simple_consumer
    end
  end


  describe '.consume' do
    it 'saves the routing key to the consumer' do
      simple_consumer.routing_keys.should include 'hutch.test1'
    end

    context 'with multiple routing keys' do
      it 'registers the class once for each routing key' do
        complex_consumer.routing_keys.should include 'hutch.test1'
        complex_consumer.routing_keys.should include 'hutch.test2'
      end
    end

    context 'when given the same routing key multiple times' do
      subject { simple_consumer.routing_keys }
      before { simple_consumer.consume 'hutch.test1' }
      its(:length) { should == 1}
    end
  end

  describe '.queue_name' do
    it 'overrides the queue name' do
      
    end
  end

  describe '.get_queue_name' do

    context 'when queue name has been set explicitly' do
      it 'returns the give queue name' do
        class Foo
          include Hutch::Consumer
          queue_name "bar"
        end

        Foo.get_queue_name.should == "bar"
      end
    end

    context 'when no queue name has been set' do
      it 'replaces module separators with colons' do
        module Foo
          class Bar
            include Hutch::Consumer
          end
        end

        Foo::Bar.get_queue_name.should == 'foo:bar'
      end

      it 'converts camelcase class names to snake case' do
        class FooBarBAZ
          include Hutch::Consumer
        end

        FooBarBAZ.get_queue_name.should == 'foo_bar_baz'
      end
    end
  end
end

