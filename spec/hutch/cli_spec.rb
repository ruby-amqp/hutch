require 'hutch/cli'
require 'tempfile'

describe Hutch::CLI do
  let(:cli) { Hutch::CLI.new }

  describe "#start_work_loop" do
    context "connection error during setup" do
      let(:error) { Hutch::ConnectionError.new }
      it "gets reported using error handlers" do
        allow(Hutch).to receive(:connect).and_raise(error)
        Hutch::Config[:error_handlers].each do |backend|
          expect(backend).to receive(:handle_setup_exception).with(error)
        end
        cli.start_work_loop
      end
    end
  end

  describe "#parse_options" do
    context "--config" do
      context "when the config file does not exist" do
        let(:file) { "/path/to/nonexistant/file" }
        before { allow(STDERR).to receive(:write) }

        it "bails" do
          expect {
            cli.parse_options(["--config=#{file}"])
          }.to raise_error SystemExit, "Config file '/path/to/nonexistant/file' not found"
        end
      end

      context "when the config file exists" do
        # Kept in a let, so the Tempfile is not garbage collected - and with it
        # unlinked - before the CLI checks that the path exists.
        let(:config_file) { Tempfile.new("hutch-test-config.yaml") }
        let(:file) { config_file.to_path }

        it "parses the config" do
          expect(Hutch::Config).to receive(:load_from_file)
          cli.parse_options(["--config=#{file}"])
        end
      end
    end

    context "--mq-tls-key" do
      context "when the keyfile file does not exist" do
        let(:file) { "/path/to/nonexistant/file" }
        before { allow(STDERR).to receive(:write) }

        it "bails" do
          expect {
            cli.parse_options(["--mq-tls-key=#{file}"])
          }.to raise_error SystemExit, "Private key file '/path/to/nonexistant/file' not found"
        end
      end

      context "when the keyfile file exists" do
        # Kept in a let, so the Tempfile is not garbage collected - and with it
        # unlinked - before the CLI checks that the path exists.
        let(:key_file) { Tempfile.new("hutch-test-key.pem") }
        let(:file) { key_file.to_path }

        it "sets mq_tls_key to the file" do
          expect(Hutch::Config).to receive(:mq_tls_key=)
          cli.parse_options(["--mq-tls-key=#{file}"])
        end
      end
    end

    context "--mq-tls-cert" do
      context "when the certfile file does not exist" do
        let(:file) { "/path/to/nonexistant/file" }
        before { allow(STDERR).to receive(:write) }

        it "bails" do
          expect {
            cli.parse_options(["--mq-tls-cert=#{file}"])
          }.to raise_error SystemExit, "Certificate file '/path/to/nonexistant/file' not found"
        end
      end

      context "when the certfile file exists" do
        # Kept in a let, so the Tempfile is not garbage collected - and with it
        # unlinked - before the CLI checks that the path exists.
        let(:cert_file) { Tempfile.new("hutch-test-cert.pem") }
        let(:file) { cert_file.to_path }

        it "sets mq_tls_cert to the file" do
          expect(Hutch::Config).to receive(:mq_tls_cert=)
          cli.parse_options(["--mq-tls-cert=#{file}"])
        end
      end
    end
  end
end
