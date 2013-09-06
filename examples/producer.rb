require 'hutch'

Hutch.connect
loop do
  print "Press return to send test message..."
  gets
  Hutch.publish('hutch.test', subject: 'test message')
  puts "Send message with routing key 'hutch.test'"
end

