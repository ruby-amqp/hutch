require 'hutch'

class TestConsumer
  include Hutch::Consumer
  consume 'hutch.test'

  def process(message)
    puts "TestConsumer got a message: #{message}"
    puts "Processing..."
    sleep(1)
    puts "Done"
  end
end
