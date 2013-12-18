require 'delegate'

module Hutch
  module Brokers
    class AmqpHandler < SimpleDelegator

      def connection_log_info
        "connecting to rabbitmq (#{protocol}#{uri})"
      end

      def exchange_log_info
        "using topic exchange '#{ mq_exchange }'"
      end

      def connection_error
        "couldn't connect to rabbitmq at #{ short_uri }"
      end

      def worker_setup_error
        'could not create exchange due to a type ' +
        'conflict with an existing exchange, ' +
        'remove the existing exchange and try again'
      end

      def bunny_params
        {
          host:      mq_host,
          port:      mq_port,
          vhost:     mq_vhost,
          tls:       mq_tls,
          tls_key:   mq_tls_key,
          tls_cert:  mq_tls_cert,
          username:  mq_username,
          password:  mq_password,
          heartbeat: 30,
          automatically_recover: true,
          network_recovery_interval: 1
        }
      end

      private

      def protocol
         mq_tls ? "amqps://" : "amqp://"
      end

      def uri
        "#{ mq_username }:#{ mq_password }@#{ mq_host }:#{ mq_port }/#{ vhost }"
      end

      def vhost
        mq_vhost.sub(/^\//, '')
      end

      def short_uri
        "#{ protocol }#{ mq_host }:#{ mq_port }"
      end
    end
  end
end
