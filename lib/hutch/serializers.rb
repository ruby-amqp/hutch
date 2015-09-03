module Hutch
  module Serializers

    class Hutch::Serializers::NotFoundError < RuntimeError ; end

    def self.register(content_type, serializer)
      self.serializers[content_type] = serializer
    end

    def self.serializers
      @serializers ||= {}
    end

    def self.find(content_type)
      serializers[content_type] || raise(Hutch::Serializers::NotFoundError, "Cannot found serializer for #{content_type.inspect}")
    end

  end
end

require 'hutch/serializers/identity'
require 'hutch/serializers/json'

