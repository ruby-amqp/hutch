require 'hutch/error_handlers/logger'
require 'erb'
require 'logger'

module Hutch
  class UnknownAttributeError < StandardError; end

  # Configuration settings, available everywhere
  #
  # There are defaults, which can be overridden by ENV variables prefixed by
  # <tt>HUTCH_</tt>, and each of these can be overridden using the {.set}
  # method.
  #
  # @example Configuring on the command-line
  #   HUTCH_PUBLISHER_CONFIRMS=false hutch
  module Config
    require 'yaml'
    STRING_KEYS = Set.new
    NUMBER_KEYS = Set.new
    BOOL_KEYS = Set.new

    # Define a String user setting
    def self.string_setting(name)
      STRING_KEYS << name
    end

    # Define a Number user setting
    def self.number_setting(name)
      NUMBER_KEYS << name
    end

    # Define a Boolean user setting
    def self.boolean_setting(name)
      BOOL_KEYS << name
    end

    string_setting :mq_host
    string_setting :mq_exchange
    string_setting :mq_vhost
    string_setting :mq_username
    string_setting :mq_password
    string_setting :mq_api_host

    number_setting :mq_port
    number_setting :mq_api_port
    number_setting :heartbeat
    number_setting :channel_prefetch
    number_setting :connection_timeout
    number_setting :read_timeout
    number_setting :write_timeout
    number_setting :graceful_exit_timeout
    number_setting :consumer_pool_size

    boolean_setting :mq_tls
    boolean_setting :mq_verify_peer
    boolean_setting :mq_api_ssl
    boolean_setting :autoload_rails
    boolean_setting :daemonise
    boolean_setting :publisher_confirms
    boolean_setting :force_publisher_confirms
    boolean_setting :enable_http_api_use
    boolean_setting :consumer_pool_abort_on_exception

    # Set of all setting keys
    ALL_KEYS = BOOL_KEYS + NUMBER_KEYS + STRING_KEYS

    def self.initialize(params = {})
      @config = default_config.merge(env_based_config).merge(params)
    end

    # Default settings
    #
    # @return [Hash]
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

    # Override defaults with ENV variables which begin with <tt>HUTCH_</tt>
    #
    # @return [Hash]
    def self.env_based_config
      env_keys_configured.each_with_object({}) {|attr, result|
        value = ENV[key_for(attr)]

        case
        when is_bool(attr) || value == 'false'
          result[attr] = to_bool(value)
        when is_num(attr)
          result[attr] = value.to_i
        else
          result[attr] = value
        end
      }
    end

    # @return [Array<Symbol>]
    def self.env_keys_configured
      ALL_KEYS.each {|attr| check_attr(attr) }

      ALL_KEYS.select { |attr| ENV.key?(key_for(attr)) }
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
      BOOL_KEYS.include?(attr)
    end

    def self.to_bool(value)
      !(value.nil? || value == '' || value =~ /^(false|f|no|n|0)$/i || value == false)
    end

    def self.is_num(attr)
      NUMBER_KEYS.include?(attr)
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
      unless default_config.key?(attr)
        raise UnknownAttributeError, "#{attr.inspect} is not a valid config attribute"
      end
    end

    def self.user_config
      @config ||= initialize
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
