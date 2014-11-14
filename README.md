![](http://cl.ly/image/3h0q3F3G142K/hutch.png)

Hutch is a Ruby library for enabling asynchronous inter-service communication
in a service-oriented architecture, using RabbitMQ.

[![Gem Version](https://badge.fury.io/rb/hutch.png)](http://badge.fury.io/rb/hutch)
[![Build Status](https://travis-ci.org/gocardless/hutch.png?branch=master)](https://travis-ci.org/gocardless/hutch)
[![Dependency Status](https://gemnasium.com/gocardless/hutch.png)](https://gemnasium.com/gocardless/hutch)
[![Code Climate](https://codeclimate.com/github/gocardless/hutch.png)](https://codeclimate.com/github/gocardless/hutch)

To install with RubyGems:

```
$ gem install hutch
```

## Project Maturity

Hutch is a relatively young project that was extracted from production systems.


## Overview

Hutch is a conventions-based framework for writing services that communicate
over RabbitMQ. Hutch is opinionated: it uses topic exchanges for message
distribution and makes some assumptions about how consumers and publishers
should work.

With Hutch, consumers are stored in separate files and include the `Hutch::Consumer` module.
They are then loaded by a command line runner which connects to RabbitMQ, sets up queues and bindings,
and so on. Publishers connect to RabbitMQ via `Hutch.connect` and publish using `Hutch.publish`.

Hutch uses [Bunny](http://rubybunny.info) under the hood.


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

By default, the queue name will be named using the consumer class. You can set
the queue name explicitly by using the `queue_name` method:

```ruby
class FailedPaymentConsumer
  include Hutch::Consumer
  consume 'gc.ps.payment.failed'
  queue_name 'failed_payments'

  def process(message)
    mark_payment_as_failed(message[:id])
  end
end
```

If you are using Hutch with Rails and want to make Hutch log to the Rails
logger rather than `stdout`, add this to `config/initializers/hutch.rb`

```ruby
Hutch::Logging.logger = Rails.logger
```

See this [RabbitMQ tutorial on topic exchanges](http://www.rabbitmq.com/tutorials/tutorial-five-ruby.html)
to learn more.


## Running Hutch

After installing the Hutch gem, you should be able to start it by simply
running `hutch` on the command line. `hutch` takes a number of options:

```console
$ hutch -h
usage: hutch [options]
        --mq-host HOST               Set the RabbitMQ host
        --mq-port PORT               Set the RabbitMQ port
    -t, --[no-]mq-tls                Use TLS for the AMQP connection
        --mq-tls-cert FILE           Certificate  for TLS client verification
        --mq-tls-key FILE            Private key for TLS client verification
        --mq-exchange EXCHANGE       Set the RabbitMQ exchange
        --mq-vhost VHOST             Set the RabbitMQ vhost
        --mq-username USERNAME       Set the RabbitMQ username
        --mq-password PASSWORD       Set the RabbitMQ password
        --mq-api-host HOST           Set the RabbitMQ API host
        --mq-api-port PORT           Set the RabbitMQ API port
    -s, --[no-]mq-api-ssl            Use SSL for the RabbitMQ API
        --config FILE                Load Hutch configuration from a file
        --require PATH               Require a Rails app or path
        --[no-]autoload-rails        Require the current rails app directory
    -q, --quiet                      Quiet logging
    -v, --verbose                    Verbose logging
        --version                    Print the version and exit
    -h, --help                       Show this message and exit
```

The first three are for configuring which RabbitMQ instance to connect to.
`--require` is covered in the next section. Configurations can also be
specified in a YAML file for convenience by passing the file location
to the --config option.  The file should look like:

```yaml
mq_username: peter
mq_password: rabbit
mq_host: broker.yourhost.com
```

Passing a setting as a command-line option will overwrite what's specified
in the config file, allowing for easy customization.



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
Hutch.connect
Hutch.publish('routing.key', subject: 'payment', action: 'received')
```

### Producer Configuration

Producers are not run with the 'hutch' command. You can specify configuration
options as follows:

```ruby
Hutch::Config.set(:mq_exchange, 'name')
```

### Publisher Confirms

For maximum message reliability when producing messages, you can force Hutch to use
[Publisher Confirms](https://www.rabbitmq.com/confirms.html) and wait for a confirmation
after every message published. This is the safest possible option for publishers
but also results in a **significant throughput drop**.

```ruby
Hutch::Config.set(:force_publisher_confirms, true)
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
- Publish messages as persistent.
- Using publisher confirms is highly recommended.

Here's an example of a well-behaved publisher, minus publisher confirms:

```ruby
AMQP.connect(host: config[:host]) do |connection|
  channel  = AMQP::Channel.new(connection)
  exchange = channel.topic(config[:exchange], durable: true)

  message = JSON.dump({ subject: 'Test', id: 'abc' })
  exchange.publish(message, routing_key: 'test', persistent: true)
end
```

If using publisher confirms with amqp gem, see [this issue][pc-issue]
and [this gist][pc-gist] for more info.

## Configuration Reference

### Config File

It is recommended to use a separate config file, unless you use URIs for connection (see below).

Known configuration parameters are:

 * `mq_host`: RabbitMQ hostname (default: `localhost`)
 * `mq_port`: RabbitMQ port (default: `5672`)
 * `mq_vhost`: vhost to use (default: `/`)
 * `mq_username`: username to use (default: `guest`, only can connect from localhost as of RabbitMQ 3.3.0)
 * `mq_password`: password to use (default: `guest`)
 * `mq_tls`: should TLS be used? (default: `false`)
 * `mq_tls_cert`: path to client TLS certificate (public key)
 * `mq_tls_key`: path to client TLS private key
 * `require_paths`: array of paths to require
 * `autoload_rails`: should Hutch command line runner try to automatically load Rails environment files?
 * `daemonise`: should Hutch runner process daemonise?
 * `pidfile`: path to PID file the runner should use
 * `channel_prefetch`: basic.qos prefetch value to use (default: `0`, no limit). See Bunny and RabbitMQ documentation.
 * `publisher_confirms`: enables publisher confirms. Leaves it up to the app how they are
                         tracked (e.g. using `Hutch::Broker#confirm_select` callback or `Hutch::Broker#wait_for_confirms`)
 * `force_publisher_confirms`: enables publisher confirms, forces `Hutch::Broker#wait_for_confirms` for every publish. **This is the safest option which also offers the lowest throughput**.
 * `log_level`: log level used by the standard Ruby logger (default: `Logger::INFO`)
 * `mq_exchange`: exchange to use for publishing (default: `hutch`)


## Supported RabbitMQ Versions

Hutch requires RabbitMQ 2.x or later. 3.x releases
are recommended.

---

GoCardless ♥ open source. If you do too, come [join us](https://gocardless.com/jobs/backend_developer).
