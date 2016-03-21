module ConsumerFactory
  @@consumer_inc ||= "0"

  def build_consumer
    @@consumer_inc = @@consumer_inc.next

    Class.new {
      include Hutch::Consumer

      consume %w( a b c )
      queue_name 'consumer' + @@consumer_inc
    }
  end
end

RSpec.configuration.after { Hutch.consumers.clear }
