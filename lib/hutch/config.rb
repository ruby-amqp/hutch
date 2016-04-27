require 'hutch/error_handlers/logger'
require 'erb'
require 'logger'

module Hutch
  class UnknownAttributeError < StandardError; end

  module Config
    require 'yaml'

    STRING_KEYS = %w(mq_host
                     mq_exchange
                     mq_vhost
                     mq_username
                     mq_password
                     mq_api_host).freeze

    NUMBER_KEYS = %w(mq_port
                     mq_api_port
                     heartbeat
                     channel_prefetch
                     connection_timeout
                     read_timeout
                     write_timeout
                     graceful_exit_timeout
                     consumer_pool_size).freeze

    BOOL_KEYS = %w(mq_tls
                   mq_verify_peer
                   mq_api_ssl
                   autoload_rails
                   daemonise
                   publisher_confirms
                   force_publisher_confirms
                   enable_http_api_use
                   consumer_pool_abort_on_exception).freeze

    ALL_KEYS = (BOOL_KEYS + NUMBER_KEYS + STRING_KEYS).freeze

    def self.initialize(params = {})
      @config = default_config.merge(env_based_config).merge(params)
    end

    def self.default_config
      {
        mq_host: '127.0.0.1',
        mq_port: 5672,
        mq_exchange: 'hutch', # TODO: should this be required?
        mq_exchange_options: {},
        mq_vhost: '/',
        mq_tls: false,
        mq_tls_cert: nil,
        mq_tls_key: nil,
        mq_tls_ca_certificates: nil,
        mq_verify_peer: true,
        mq_username: 'guest',
        mq_password: 'guest',
        mq_api_host: '127.0.0.1',
        mq_api_port: 15_672,
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
        setup_procs: [],
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

        serializer: Hutch::Serializers::JSON
      }
    end

    # Override defaults with ENV variables which begin with HUTCH_
    def self.env_based_config
      ALL_KEYS.each_with_object({}) {|attr_name, result|
        attr = attr_name.to_sym
        check_attr(attr)
        next unless ENV.key?(key_for(attr))
        value = ENV[key_for(attr)]

        case
        when value.nil?
          # Can not set nil via ENV vars
        when is_bool(attr) || value == 'false'
          result[attr] = to_bool(value)
        when is_num(attr)
          result[attr] = value.to_i
        else
          result[attr] = value
        end
      }
    end

    def self.reset!
      @config = initialize
    end

    def self.get(attr)
      check_attr(attr)
      user_config[attr]
    end

    def self.key_for(attr)
      key = attr.to_s.gsub('.', '__').upcase
      "HUTCH_#{key}"
    end

    def self.is_bool(attr)
      BOOL_KEYS.include?(attr.to_s)
    end

    def self.to_bool(value)
      !(value.nil? || value == '' || value =~ /^(false|f|no|n|0)$/i || value == false)
    end

    def self.is_num(attr)
      NUMBER_KEYS.include?(attr.to_s)
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
      unless default_config.key?(attr.to_sym)
        raise UnknownAttributeError, "#{attr.inspect} is not a valid config attribute"
      end
    end

    def self.user_config
      @config ||= initialize(default_config.merge(env_based_config))
    end

    def self.to_hash
      user_config
    end

    def self.load_from_file(file)
      YAML.load(ERB.new(File.read(file)).result).each do |attr, value|
        Hutch::Config.send("#{attr}=", convert_value(attr, value))
      end
    end

    def self.convert_value(attr, value)
      case attr
      when 'tracer'
        Kernel.const_get(value)
      else
        value
      end
    end

    def self.method_missing(method, *args, &block)
      attr = method.to_s.sub(/=$/, '').to_sym
      return super unless default_config.key?(attr)

      if method =~ /=$/
        set(attr, args.first)
      else
        get(attr)
      end
    end
  end
end
