require 'hutch'

Hutch.connect
loop do
  Hutch.publish('hutch.test', subject: 'test message')
  sleep 0.5
end

