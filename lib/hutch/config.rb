require 'hutch/error_handlers/logger'
require 'hutch/tracers'
require 'hutch/serializers/json'
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
    @string_keys = Set.new
    @number_keys = Set.new
    @boolean_keys = Set.new
    @settings_defaults = {}

    # Define a String user setting
    # @!visibility private
    def self.string_setting(name, default_value)
      @string_keys << name
      @settings_defaults[name] = default_value
    end

    # Define a Number user setting
    # @!visibility private
    def self.number_setting(name, default_value)
      @number_keys << name
      @settings_defaults[name] = default_value
    end

    # Define a Boolean user setting
    # @!visibility private
    def self.boolean_setting(name, default_value)
      @boolean_keys << name
      @settings_defaults[name] = default_value
    end

    # RabbitMQ hostname
    string_setting :mq_host, '127.0.0.1'

    # RabbitMQ Exchange to use for publishing
    string_setting :mq_exchange, 'hutch'

    # RabbitMQ Exchange type to use for publishing
    string_setting :mq_exchange_type, 'topic'

    # RabbitMQ vhost to use
    string_setting :mq_vhost, '/'

    # RabbitMQ username to use.
    #
    # As of RabbitMQ 3.3.0, <tt>guest</tt> can only can connect from localhost.
    string_setting :mq_username, 'guest'

    # RabbitMQ password
    string_setting :mq_password, 'guest'

    # RabbitMQ URI (takes precedence over MQ username, password, host, port and vhost settings)
    string_setting :uri, nil

    # RabbitMQ HTTP API hostname
    string_setting :mq_api_host, '127.0.0.1'

    # RabbitMQ port
    number_setting :mq_port, 5672

    # RabbitMQ HTTP API port
    number_setting :mq_api_port, 15672

    # [RabbitMQ heartbeat timeout](http://rabbitmq.com/heartbeats.html)
    number_setting :heartbeat, 30

    # The <tt>basic.qos</tt> prefetch value to use.
    #
    # Default: `0`, no limit. See Bunny and RabbitMQ documentation.
    number_setting :channel_prefetch, 0

    # Bunny's socket open timeout
    number_setting :connection_timeout, 11

    # Bunny's socket read timeout
    number_setting :read_timeout, 11

    # Bunny's socket write timeout
    number_setting :write_timeout, 11

    # Bunny's enable/disable network recovery
    boolean_setting :automatically_recover, true

    # Bunny's reconnect interval
    number_setting :network_recovery_interval, 1

    # FIXME: DOCUMENT THIS
    number_setting :graceful_exit_timeout, 11

    # Bunny consumer work pool size
    number_setting :consumer_pool_size, 1

    # Should TLS be used?
    boolean_setting :mq_tls, false

    # Should SSL certificate be verified?
    boolean_setting :mq_verify_peer, true

    # Should SSL be used for the RabbitMQ API?
    boolean_setting :mq_api_ssl, false

    # Should the current Rails app directory be required?
    boolean_setting :autoload_rails, true

    # Should the Hutch runner process daemonise?
    #
    # The option is ignored on JRuby.
    boolean_setting :daemonise, false

    # Should RabbitMQ publisher confirms be enabled?
    #
    # Leaves it up to the app how they are tracked
    # (e.g. using Hutch::Broker#confirm_select callback or Hutch::Broker#wait_for_confirms)
    boolean_setting :publisher_confirms, false

    # Enables publisher confirms, forces Hutch::Broker#wait_for_confirms for
    # every publish.
    #
    # **This is the safest option which also offers the
    # lowest throughput**.
    boolean_setting :force_publisher_confirms, false

    # Should the RabbitMQ HTTP API be used?
    boolean_setting :enable_http_api_use, true

    # Should Bunny's consumer work pool threads abort on exception.
    #
    # The option is ignored on JRuby.
    boolean_setting :consumer_pool_abort_on_exception, false

    # Prefix displayed on the consumers tags.
    string_setting :consumer_tag_prefix, 'hutch'

    # A namespace to help group your queues
    string_setting :namespace, nil

    string_setting :group, ''

    # Set of all setting keys
    ALL_KEYS = @boolean_keys + @number_keys + @string_keys

    def self.initialize(params = {})
      unless @config
        @config = default_config
        define_methods
        @config.merge!(env_based_config)
      end
      @config.merge!(params)
      @config
    end

    # Default settings
    #
    # @return [Hash]
    def self.default_config
      @settings_defaults.merge({
        mq_exchange_options: {},
        mq_tls_cert: nil,
        mq_tls_key: nil,
        mq_tls_ca_certificates: nil,
        uri: nil,
        log_level: Logger::INFO,
        client_logger: nil,
        require_paths: [],
        error_handlers: [Hutch::ErrorHandlers::Logger.new],
        # note that this is not a list, it is a chain of responsibility
        # that will fall back to "nack unconditionally"
        error_acknowledgements: [],
        setup_procs: [],
        consumer_groups: {},
        tracer: Hutch::Tracers::NullTracer,
        namespace: nil,
        pidfile: nil,
        serializer: Hutch::Serializers::JSON
      })
    end

    # Override defaults with ENV variables which begin with <tt>HUTCH_</tt>
    #
    # @return [Hash]
    def self.env_based_config
      env_keys_configured.each_with_object({}) {|attr, result|
        value = ENV[key_for(attr)]

        result[attr] = type_cast(attr, value)
      }
    end

    # @return [Array<Symbol>]
    def self.env_keys_configured
      ALL_KEYS.each {|attr| check_attr(attr) }

      ALL_KEYS.select { |attr| ENV.key?(key_for(attr)) }
    end

    def self.get(attr)
      check_attr(attr.to_sym)
      user_config[attr.to_sym]
    end

    def self.key_for(attr)
      key = attr.to_s.gsub('.', '__').upcase
      "HUTCH_#{key}"
    end

    def self.is_bool(attr)
      @boolean_keys.include?(attr)
    end

    def self.to_bool(value)
      !(value.nil? || value == '' || value =~ /^(false|f|no|n|0)$/i || value == false)
    end

    def self.is_num(attr)
      @number_keys.include?(attr)
    end

    def self.set(attr, value)
      check_attr(attr.to_sym)
      user_config[attr.to_sym] = type_cast(attr, value)
    end

    class << self
      alias_method :[],  :get
      alias_method :[]=, :set
    end

    def self.check_attr(attr)
      unless user_config.key?(attr)
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

    def self.type_cast(attr, value)
      case
      when is_bool(attr) || value == 'false'
        to_bool(value)
      when is_num(attr)
        value.to_i
      else
        value
      end
    end
    private_class_method :type_cast

    def self.define_methods
      @config.keys.each do |key|
        define_singleton_method(key) do
          get(key)
        end

        define_singleton_method("#{key}=") do |val|
          set(key, val)
        end
      end
    end
  end
end
Hutch::Config.initialize
