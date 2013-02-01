require 'hutch'

class TestConsumer
  include Hutch::Consumer
  consume 'hutch.test'

  def process(message)
    puts "TestConsumer got a message: #{message}"
  end
end
