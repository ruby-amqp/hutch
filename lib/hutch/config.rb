require 'hutch/error_handlers/logger'
require 'hutch/setup/queues'
require 'erb'
require 'logger'

module Hutch
  class UnknownAttributeError < StandardError; end

  module Config
    require 'yaml'

    def self.initialize(params = {})
      @config = {
        mq_host: 'localhost',
        mq_port: 5672,
        mq_exchange: 'hutch',  # TODO: should this be required?
        mq_exchange_options: {},
        mq_vhost: '/',
        mq_tls: false,
        mq_tls_cert: nil,
        mq_tls_key: nil,
        mq_tls_ca_certificates: nil,
        mq_verify_peer: true,
        mq_username: 'guest',
        mq_password: 'guest',
        mq_api_host: 'localhost',
        mq_api_port: 15672,
        mq_api_ssl: false,
        heartbeat: 30,
        # placeholder, allows specifying connection parameters
        # as a URI.
        uri: nil,
        log_level: Logger::INFO,
        require_paths: [],
        autoload_rails: true,
        error_handlers: [Hutch::ErrorHandlers::Logger.new],
        # note that this is not a list, it is a chain of responsibility
        # that will fall back to "nack unconditionally"
        error_acknowledgements: [],
        tracer: Hutch::Tracers::NullTracer,
        namespace: nil,
        daemonise: false,
        pidfile: nil,
        channel_prefetch: 0,
        # enables publisher confirms, leaves it up to the app
        # how they are tracked
        publisher_confirms: false,
        # like `publisher_confirms` above but also
        # forces waiting for a confirm for every publish
        force_publisher_confirms: false,
        # Heroku needs > 10. MK.
        connection_timeout: 11,
        read_timeout: 11,
        write_timeout: 11,
        enable_http_api_use: true,
        # Number of seconds that a running consumer is given
        # to finish its job when gracefully exiting Hutch, before
        # it's killed.
        graceful_exit_timeout: 11,
        client_logger: nil,

        consumer_pool_size: 1,
        consumer_pool_abort_on_exception: false,

        serializer: Hutch::Serializers::JSON,
        setup_procs: [ Hutch::Setup::Queues ]
      }.merge(params)
    end

    def self.get(attr)
      check_attr(attr)
      user_config[attr]
    end

    def self.set(attr, value)
      check_attr(attr)
      user_config[attr] = value
    end

    class << self
      alias_method :[],  :get
      alias_method :[]=, :set
    end

    def self.check_attr(attr)
      unless user_config.key?(attr)
        raise UnknownAttributeError, "#{attr} is not a valid config attribute"
      end
    end

    def self.user_config
      initialize unless @config
      @config
    end

    def self.to_hash
      self.user_config
    end

    def self.load_from_file(file)
      YAML.load(ERB.new(File.read(file)).result).each do |attr, value|
        Hutch::Config.send("#{attr}=", convert_value(attr, value))
      end
    end

    def self.convert_value(attr, value)
      case attr
      when "tracer"
        Kernel.const_get(value)
      else
        value
      end
    end

    def self.method_missing(method, *args, &block)
      attr = method.to_s.sub(/=$/, '').to_sym
      return super unless user_config.key?(attr)

      if method =~ /=$/
        set(attr, args.first)
      else
        get(attr)
      end
    end

    private

    def deep_copy(obj)
      Marshal.load(Marshal.dump(obj))
    end
  end
end
