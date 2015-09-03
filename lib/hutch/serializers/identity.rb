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

      Hutch::Serializers.register(nil, self)
    end
  end
end
