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

    context "--mq-tls-key" do
      context "when the keyfile file does not exist" do
        let(:file) { "/path/to/nonexistant/file" }
        before { STDERR.stub(:write) }

        it "bails" do
          expect {
            cli.parse_options(["--mq-tls-key=#{file}"])
          }.to raise_error SystemExit
        end
      end

      context "when the keyfile file exists" do
        let(:file) do
          Tempfile.new("hutch-test-key.pem").to_path
        end

        it "sets mq_tls_key to the file" do
          Hutch::Config.should_receive(:mq_tls_key=)
          cli.parse_options(["--mq-tls-key=#{file}"])
        end
      end
    end

    context "--mq-tls-cert" do
      context "when the certfile file does not exist" do
        let(:file) { "/path/to/nonexistant/file" }
        before { STDERR.stub(:write) }

        it "bails" do
          expect {
            cli.parse_options(["--mq-tls-cert=#{file}"])
          }.to raise_error SystemExit
        end
      end

      context "when the certfile file exists" do
        let(:file) do
          Tempfile.new("hutch-test-cert.pem").to_path
        end

        it "sets mq_tls_cert to the file" do
          Hutch::Config.should_receive(:mq_tls_cert=)
          cli.parse_options(["--mq-tls-cert=#{file}"])
        end
      end
    end
  end
end
