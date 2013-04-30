require 'hutch'

Hutch.connect
  loop do
    Hutch.publish('hutch.test', {subject: 'test message'}, true)
    sleep 0.5
  end

