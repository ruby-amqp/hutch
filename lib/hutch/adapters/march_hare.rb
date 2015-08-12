require 'march_hare'

module Hutch
  module Adapters
    class MarchHareAdapter
      DEFAULT_VHOST = "/"

      def prefetch_channel(ch, prefetch)
        ch.prefetch = prefetch if prefetch
      end
    end
  end
end
