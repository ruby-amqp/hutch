require 'hutch/logging'
require 'honeybadger'

module Hutch
  module ErrorHandlers
    class Honeybadger
      include Logging

      def handle(properties, payload, consumer, ex)
        message_id = properties.message_id
        prefix = "message(#{message_id || '-'}):"
        logger.error "#{prefix} Logging event to Honeybadger"
        logger.error "#{prefix} #{ex.class} - #{ex.message}"
        ::Honeybadger.notify_or_ignore(
          :error_class => ex.class.name,
          :error_message => "#{ ex.class.name }: #{ ex.message }",
          :backtrace => ex.backtrace,
          :context => {
            :message_id => message_id,
            :consumer => consumer
          },
          :parameters => {
            :payload => payload
          }
        )
      end
    end
  end
end
