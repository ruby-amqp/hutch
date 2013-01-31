# Hutch

A system for processing messages from RabbitMQ. Messages should be sent over
topic exchanges, and encoded with JSON.


## Defining Consumers

Consumers receive messages from a RabbitMQ queue. That queue may be bound to
one or more topics (represented by routing keys).

To create a consumer, include the `Hutch::Consumer` module in a class that
defines a `#process` method. `#process` should take a single argument, which
will be a `Message` object. The `Message` object encapsulates the message data,
along with any associated metadata. To access properties of the message, use
Hash-style indexing syntax:

```ruby
message[:id]  # => "02ABCXYZ"
```

To subscribe to a topic, pass a routing key to `consume` in the class
definition. To bind to multiple routing keys, simply pass extra routing keys
in as additional arguments. Refer to the [RabbitMQ docs on topic exchanges
][topic-docs] for more information about how to use routing keys. Here's an
example consumer:

```ruby
class FailedPaymentConsumer
  include Hutch::Consumer
  consume 'gc.ps.payment.failed'

  def process(message)
    mark_payment_as_failed(message[:id])
  end
end
```

[topic-docs]: http://www.rabbitmq.com/tutorials/tutorial-five-python.html


## Running Hutch

After installing the Hutch gem, you should be able to start it by simply
running `hutch` on the command line. `hutch` takes a number of options:

```console
$ hutch -h
usage: hutch [options]
        --rabbitmq-host HOST         Set the RabbitMQ host
        --rabbitmq-port PORT         Set the RabbitMQ port
        --rabbitmq-exchange PORT     Set the RabbitMQ exchange
        --require PATH               Require a Rails app or path
    -q, --quiet                      Quiet logging
    -v, --verbose                    Verbose logging
        --version                    Print the version and exit
    -h, --help                       Show this message and exit
```

The first three are for configuring which RabbitMQ instance to connect to.
`--require` is covered in the next section. The remainder are self-explanatory.

### Loading Consumers

Using Hutch with a Rails app is simple. Either start Hutch in the working
directory of a Rails app, or pass the path to a Rails app in with the
`--require` option. Consumers defined in Rails apps should be placed with in
the `app/consumers/` directory, to allow them to be auto-loaded when Rails
boots.

To require files that define consumers manually, simply pass each file as an
option to `--require`. Hutch will automatically detect whether you've provided
a Rails app or a standard file, and take the appropriate behaviour:

```bash
$ hutch --require path/to/rails-app  # loads a rails app
$ hutch --require path/to/file.rb    # loads a ruby file
```

## Producers

Hutch includes a `publish` method for sending messages to Hutch consumers. When
possible, this should be used, rather than directly interfacing with RabbitMQ
libraries.

```ruby
Hutch.publish('routing.key', subject: 'payment', action: 'received')
```

### Writing Well-Behaved Publishers

You may need to send messages to Hutch from languages other than Ruby. This
prevents the use of `Hutch.publish`, requiring custom publication code to be
written. There are a few things to keep in mind when writing producers that
send messages to Hutch.

- Make sure that the producer exchange name matches the exchange name that
  Hutch is using.
- Hutch works with topic exchanges, check the producer is also using topic
  exchanges.
- Use message routing keys that match those used in your Hutch consumers.
- Be sure your exchanges are marked as durable. In the Ruby AMQP gem, this is
  done by passing `durable: true` to the exchange creation method.
- Mark your messages as persistent. This is done by passing `persistent: true`
  to the publish method in Ruby AMQP.
- Wrapping publishing code in transactions or using publisher confirms is
  highly recommended. This can be slightly tricky, see [this issue](pc-issue)
  and [this gist](pc-gist) for more info.

Here's an example of a well-behaved publisher, minus publisher confirms:

```ruby
AMQP.connect(host: config[:host]) do |connection|
  channel  = AMQP::Channel.new(connection)
  exchange = channel.topic(config[:exchange], durable: true)

  message = JSON.dump({ subject: 'Test', id: 'abc' })
  exchange.publish(message, routing_key: 'test', persistent: true)
end
```

[pc-issue]: https://github.com/ruby-amqp/amqp/issues/92
[pc-gist]: https://gist.github.com/3042381

