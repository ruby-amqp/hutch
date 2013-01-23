# Hutch

A system for processing messages from RabbitMQ.


## Defining Consumers

```ruby
class FailedPaymentConsumer
  include Hutch::Consumer
  consume 'gc.ps.payment.failed'

  def process(message)
    mark_payment_as_failed(message[:id])
  end
end
```

