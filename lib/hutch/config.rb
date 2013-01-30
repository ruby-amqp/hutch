require 'logger'

module Hutch
  class UnknownAttributeError < StandardError; end

  module Config
    DEFAULTS = {
      mq_host: 'localhost',
      mq_port: 5672,
      mq_exchange: 'hutch',  # TODO: should this be required?
      mq_api_port: 55672,
      mq_api_user: 'guest',
      mq_api_password: 'guest',
      log_level: Logger::INFO,
      require_paths: []
    }

    def self.get(attr)
      check_attr(attr)
      user_config.fetch(attr, DEFAULTS[attr])
    end

    def self.set(attr, value)
      check_attr(attr)
      user_config[attr] = value
    end

    def self.check_attr(attr)
      unless DEFAULTS.key?(attr)
        raise UnknownAttributeError, "#{attr} is not a valid config attribute"
      end
    end

    def self.user_config
      @config ||= {}
    end

    def self.method_missing(method, *args, &block)
      attr = method.to_s.sub(/=$/, '').to_sym
      return super unless DEFAULTS.key?(attr)

      if method =~ /=$/
        set(attr, args.first)
      else
        get(attr)
      end
    end
  end
end
