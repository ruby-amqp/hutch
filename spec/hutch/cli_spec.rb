require 'hutch/cli'
require 'tempfile'

describe Hutch::CLI do
  let(:cli) { Hutch::CLI.new }

  describe "#parse_options" do
    context "--config" do
      context "when the config file does not exist" do
        let(:file) { "/path/to/nonexistant/file" }
        before { STDERR.stub(:write) }

        it "bails" do
          expect {
            cli.parse_options(["--config=#{file}"])
          }.to raise_error SystemExit
        end
      end

      context "when the config file exists" do
        let(:file) do
          Tempfile.new("hutch-test-config.yaml").to_path
        end

        it "parses the config" do
          Hutch::Config.should_receive(:load_from_file)
          cli.parse_options(["--config=#{file}"])
        end
      end
    end
  end
end
