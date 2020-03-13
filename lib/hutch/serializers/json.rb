require 'multi_json'
require 'active_support/core_ext/hash/indifferent_access'

module Hutch
  module Serializers
    class JSON

      def self.encode(payload)
        ::JSON.dump(payload)
      end

      def self.decode(payload)
        ::MultiJson.load(to_be_decoded(payload))
          .with_indifferent_access
      end

      def self.binary? ; false ; end

      def self.content_type ; 'application/json' ; end

      def self.to_be_decoded(payload)
        (payload || '{}')
      end

    end
  end
end
