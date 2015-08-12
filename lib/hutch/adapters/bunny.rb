require 'bunny'

module Hutch
  module Adapters
    class BunnyAdapter
      DEFAULT_VHOST = Bunny::Session::DEFAULT_VHOST

      def prefetch_channel(ch, prefetch)
        ch.prefetch(prefetch) if prefetch
      end
    end
  end
end
