require 'delegate'

module Hutch
  module BrokerHandlers
    class Api < SimpleDelegator

      def carrot_top_params
        {
          host:     mq_api_host,
          port:     mq_api_port,
          user:     mq_username,
          password: mq_password,
          ssl:      mq_api_ssl
        }
      end

      def connection_info
        "connecting to rabbitmq management api (#{ uri })"
      end

      def connection_error
        "couldn't connect to api at #{ uri }"
      end

      private

      def protocol
        mq_api_ssl ? "https://" : "http://"
      end

      def uri
        "#{ protocol }#{ mq_username }:#{ mq_password }@#{ mq_api_host }:#{ mq_api_port }/"
      end
    end
  end
end
