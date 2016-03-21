require 'spec_helper'
require 'hutch/worker'

describe Hutch::Worker do
  let(:setup_procs) { Array.new(2) { Proc.new {} } }
  let(:broker) { instance_double("Hutch::Broker") }
  let(:worker) { subject }

  describe "#run" do
    around do |ex|
      old_procs = Hutch::Config[:setup_procs]
      Hutch::Config[:setup_procs] = setup_procs
      ex.run
      Hutch::Config[:setup_procs] = old_procs
    end

    it "starts a worker by calling things in the proper order" do
      expect(Hutch).to receive(:connect).ordered
      setup_procs.each do |prc|
        expect(prc).to receive(:call).ordered
      end
      expect(Hutch::MainLoop).to receive(:loop_until_signaled).ordered
      allow(Hutch).to receive(:broker).and_return(broker)
      expect(broker).to receive(:stop).ordered

      worker.run
    end
  end
end
