require 'bunny'

module Hutch
  module BrokerHandlers
    def with_authentication_error_handler
      yield
    rescue Net::HTTPServerException => ex
      logger.error "HTTP API connection error: #{ex.message.downcase}"
      if ex.response.code == '401'
        raise AuthenticationError, 'invalid HTTP API credentials'
      else
        raise
      end
    end

    def with_connection_error_handler
      yield
    rescue Errno::ECONNREFUSED => ex
      logger.error "HTTP API connection error: #{ex.message.downcase}"
      raise ConnectionError, "couldn't connect to HTTP API at #{api_config.sanitized_uri}"
    end

    def with_bunny_precondition_handler(item)
      yield
    rescue Bunny::PreconditionFailed => ex
      logger.error ex.message
      s = "RabbitMQ responded with 406 Precondition Failed when creating this #{item}. " \
          'Perhaps it is being redeclared with non-matching attributes'
      raise WorkerSetupError, s
    end

    def with_bunny_connection_handler(uri)
      yield
    rescue Bunny::TCPConnectionFailed => ex
      logger.error "amqp connection error: #{ex.message.downcase}"
      raise ConnectionError, "couldn't connect to rabbitmq at #{uri}. Check your configuration, network connectivity and RabbitMQ logs."
    end
  end
end
