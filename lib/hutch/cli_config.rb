require 'hutch/config'
module Hutch
  module CLIConfig
    private
    def opt_host(opts)
      opts.on('--mq-host HOST', 'Set the RabbitMQ host') do |host|
        Hutch::Config.mq_host = host
      end
    end

    def opt_port(opts)
      opts.on('--mq-port PORT', 'Set the RabbitMQ port') do |port|
        Hutch::Config.mq_port = port
      end
    end

    def opt_tls(opts)
      opts.on("-t", "--[no-]mq-tls", 'Use TLS for the AMQP connection') do |tls|
        Hutch::Config.mq_tls = tls
      end
    end

    def opt_cert_file(opts)
      opts.on('--mq-tls-cert FILE', 'Certificate for TLS client verification') do |file|
        abort_without_file(file, 'Certificate file') do
          Hutch::Config.mq_tls_cert = file
        end
      end
    end

    def opt_key_file(opts)
      opts.on('--mq-tls-key FILE', 'Private key for TLS client verification') do |file|
        abort_without_file(file, 'Private key file') do
          Hutch::Config.mq_tls_key = file
        end
      end
    end

    def opt_exchange(opts)
      opts.on('--mq-exchange EXCHANGE',
              'Set the RabbitMQ exchange') do |exchange|
        Hutch::Config.mq_exchange = exchange
      end
    end

    def opt_vhost(opts)
      opts.on('--mq-vhost VHOST', 'Set the RabbitMQ vhost') do |vhost|
        Hutch::Config.mq_vhost = vhost
      end
    end

    def opt_username(opts)
      opts.on('--mq-username USERNAME',
              'Set the RabbitMQ username') do |username|
        Hutch::Config.mq_username = username
      end
    end

    def opt_password(opts)
      opts.on('--mq-password PASSWORD',
              'Set the RabbitMQ password') do |password|
        Hutch::Config.mq_password = password
      end
    end

    def opt_api_host(opts)
      opts.on('--mq-api-host HOST', 'Set the RabbitMQ API host') do |host|
        Hutch::Config.mq_api_host = host
      end
    end

    def opt_api_port(opts)
      opts.on('--mq-api-port PORT', 'Set the RabbitMQ API port') do |port|
        Hutch::Config.mq_api_port = port
      end
    end

    def opt_api_ssl(opts)
      opts.on("-s", "--[no-]mq-api-ssl", 'Use SSL for the RabbitMQ API') do |api_ssl|
        Hutch::Config.mq_api_ssl = api_ssl
      end
    end

    def opt_config_file(opts)
      opts.on('--config FILE', 'Load Hutch configuration from a file') do |file|
        begin
          File.open(file) { |fp| Hutch::Config.load_from_file(fp) }
        rescue Errno::ENOENT
          abort_with_message("Config file '#{file}' not found")
        end
      end
    end

    def opt_path(opts)
      opts.on('--require PATH', 'Require a Rails app or path') do |path|
        Hutch::Config.require_paths << path
      end
    end

    def opt_autoload_rails(opts)
      opts.on('--[no-]autoload-rails', 'Require the current rails app directory') do |autoload_rails|
        Hutch::Config.autoload_rails = autoload_rails
      end
    end

    def opt_quiet_logging(opts)
      opts.on('-q', '--quiet', 'Quiet logging') do
        Hutch::Config.log_level = Logger::WARN
      end
    end

    def opt_verbose_logging(opts)
      opts.on('-v', '--verbose', 'Verbose logging') do
        Hutch::Config.log_level = Logger::DEBUG
      end
    end

    def opt_namespace(opts)
      opts.on('--namespace NAMESPACE', 'Queue namespace') do |namespace|
        Hutch::Config.namespace = namespace
      end
    end

    def opt_daemonise(opts)
      opts.on('-d', '--daemonise', 'Daemonise') do |daemonise|
        Hutch::Config.daemonise = daemonise
      end
    end

    def opt_pidfile(opts)
      opts.on('--pidfile PIDFILE', 'Pidfile') do |pidfile|
        Hutch::Config.pidfile = pidfile
      end
    end

    def opt_print_version(opts)
      opts.on('--version', 'Print the version and exit') do
        puts "hutch v#{VERSION}"
        exit 0
      end
    end

    def opt_print_help(opts)
      opts.on('-h', '--help', 'Show this message and exit') do
        puts opts
        exit 0
      end
    end

    def abort_without_file(file, file_description, &block)
      abort_with_message("#{file_description} '#{file}' not found") unless File.exists?(file)

      yield
    end

    def abort_with_message(message)
      abort message
    end
  end
end
