require 'hutch/error_handlers/logger'
require 'logger'

module Hutch
  class UnknownAttributeError < StandardError; end

  module Config
    require 'yaml'

    def self.initialize
      @config = {
        mq_host: 'localhost',
        mq_port: 5672,
        mq_exchange: 'hutch',  # TODO: should this be required?
        mq_vhost: '/',
        mq_tls: false,
        mq_tls_cert: nil,
        mq_tls_key: nil,
        mq_username: 'guest',
        mq_password: 'guest',
        mq_api_host: 'localhost',
        mq_api_port: 15672,
        mq_api_ssl: false,
        log_level: Logger::INFO,
        require_paths: [],
        autoload_rails: true,
        error_handlers: [Hutch::ErrorHandlers::Logger.new],
        namespace: nil,
        channel_prefetch: 0
      }
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

    def self.load_from_file(file)
      YAML.load(file).each do |attr, value|
        Hutch::Config.send("#{attr}=", value)
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
