module Hutch
  module Serializers
    class Identity

      def self.encode(payload)
        payload
      end

      def self.decode(payload)
        payload
      end

      def self.binary? ; false ; end

      def self.content_type ; nil ; end

    end
  end
end
