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
        arguments foo: :bar
      end
    end
    ComplexConsumer
  end

  describe 'module inclusion' do
    it 'registers the class as a consumer' do
      expect(Hutch).to receive(:register_consumer) do |klass|
        expect(klass).to eq(simple_consumer)
      end

      simple_consumer
    end
  end

  describe '.consume' do
    it 'saves the routing key to the consumer' do
      expect(simple_consumer.routing_keys).to include 'hutch.test1'
    end

    context 'with multiple routing keys' do
      it 'registers the class once for each routing key' do
        expect(complex_consumer.routing_keys).to include 'hutch.test1'
        expect(complex_consumer.routing_keys).to include 'hutch.test2'
      end
    end

    context 'when given the same routing key multiple times' do
      subject { simple_consumer.routing_keys }
      before { simple_consumer.consume 'hutch.test1' }

      describe '#length' do
        subject { super().length }
        it { is_expected.to eq(1) }
      end
    end
  end

  describe '.queue_name' do
    let(:queue_name) { 'foo' }

    it 'overrides the queue name' do
      simple_consumer.queue_name(queue_name)
      expect(simple_consumer.get_queue_name).to eq(queue_name)
    end
  end

  describe '.arguments' do
    let(:args) { { foo: :bar} }

    it 'overrides the arguments' do
      simple_consumer.arguments(args)
      expect(simple_consumer.get_arguments).to eq(args)
    end

  end

  describe '.get_arguments' do

    context 'when defined' do
      it { expect(complex_consumer.get_arguments).to eq(foo: :bar) }
    end

    context 'when not defined' do
      it { expect(simple_consumer.get_arguments).to eq({}) }
    end

  end

  describe '.get_queue_name' do

    context 'when queue name has been set explicitly' do
      it 'returns the give queue name' do
        class Foo
          include Hutch::Consumer
          queue_name 'bar'
        end

        expect(Foo.get_queue_name).to eq('bar')
      end
    end

    context 'when no queue name has been set' do
      it 'replaces module separators with colons' do
        module Foo
          class Bar
            include Hutch::Consumer
          end
        end

        expect(Foo::Bar.get_queue_name).to eq('foo:bar')
      end

      it 'converts camelcase class names to snake case' do
        class FooBarBAZ
          include Hutch::Consumer
        end

        expect(FooBarBAZ.get_queue_name).to eq('foo_bar_baz')
      end
    end
  end
end
