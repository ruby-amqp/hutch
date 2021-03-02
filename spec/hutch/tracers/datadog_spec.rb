require 'spec_helper'

RSpec.describe Hutch::Tracers::Datadog do
  describe "#handle" do
    subject(:handle) { tracer.handle(message) }

    let(:tracer) { described_class.new(klass) }
    let(:klass)  do
      Class.new do
        attr_reader :message

        def initialize
          @message = nil
        end

        def class
          OpenStruct.new(name: 'ClassName')
        end

        def process(message)
          @message = message
        end
      end.new
    end
    let(:message) { double(:message) }

    before do
      allow(Datadog.tracer).to receive(:trace).and_call_original
    end

    it 'uses Datadog tracer' do
      handle

      expect(Datadog.tracer).to have_received(:trace).with('ClassName',
        hash_including(service: 'hutch', span_type: 'rabbitmq'))
    end

    it 'processes the message' do
      expect {
        handle
      }.to change { klass.message }.from(nil).to(message)
    end
  end
end
