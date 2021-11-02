![](http://cl.ly/image/3h0q3F3G142K/hutch.png)

[![Gem Version](https://badge.fury.io/rb/hutch.svg)](http://badge.fury.io/rb/hutch)
[![Code Climate](https://codeclimate.com/github/gocardless/hutch.svg)](https://codeclimate.com/github/gocardless/hutch)

Hutch is a Ruby library for enabling asynchronous inter-service communication
in a service-oriented architecture, using RabbitMQ.

To install with RubyGems:

```
gem install hutch
```

<!-- Tocer[start]: Auto-generated, don't remove. -->

### Table of Contents

  - [Requirements](#requirements)
  - [Overview](#overview)
    - [Project Maturity](#project-maturity)
  - [Consumers](#consumers)
    - [Message Processing Tracers](#message-processing-tracers)
  - [Running Hutch](#running-hutch)
    - [Loading Consumers](#loading-consumers)
    - [Stopping Hutch](#stopping-hutch)
  - [Producers](#producers)
    - [Producer Configuration](#producer-configuration)
    - [Publisher Confirms](#publisher-confirms)
    - [Writing Well-Behaved Publishers](#writing-well-behaved-publishers)
  - [Configuration](#configuration)
    - [Config File](#config-file)
    - [Environment variables](#environment-variables)
    - [Configuration precedence](#configuration-precedence)
    - [Generated list of configuration options](#generated-list-of-configuration-options)

<!-- Tocer[finish]: Auto-generated, don't remove. -->

## Requirements

- Hutch requires Ruby 2.4+ or JRuby 9K.
- Hutch requires RabbitMQ 3.3 or later.

## Overview

Hutch is a conventions-based framework for writing services that communicate
over RabbitMQ. Hutch is opinionated: it uses topic exchanges for message
distribution and makes some assumptions about how consumers and publishers
should work.

With Hutch, consumers are stored in separate files and include the `Hutch::Consumer` module.
They are then loaded by a command line runner which connects to RabbitMQ, sets up queues and bindings,
and so on. Publishers connect to RabbitMQ via `Hutch.connect` and publish using `Hutch.publish`.

Hutch uses [Bunny](http://rubybunny.info) or [March Hare](http://rubymarchhare.info)
(on JRuby) under the hood.

### Project Maturity

Hutch is a mature project that was originally extracted from production systems
at [GoCardless](https://gocardless.com) in 2013 and is now maintained by its contributors
and users.

## Consumers

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
](http://www.rabbitmq.com/tutorials/tutorial-five-ruby.html) for more information
about how to use routing keys. Here's an example consumer:

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

It is possible to set some custom options to consumer's queue explicitly.
This example sets the consumer's queue as a
[quorum queue](https://www.rabbitmq.com/quorum-queues.html)
and to operate in the [lazy mode](https://www.rabbitmq.com/lazy-queues.html).
The `initial_group_size`
[argument](https://www.rabbitmq.com/quorum-queues.html#replication-factor) is
optional.

```ruby
class FailedPaymentConsumer
  include Hutch::Consumer
  consume 'gc.ps.payment.failed'
  queue_name 'failed_payments'
  lazy_queue
  quorum_queue initial_group_size: 3

  def process(message)
    mark_payment_as_failed(message[:id])
  end
end
```

You can also set custom arguments per consumer. This example declares a consumer with
a maximum length of 10 messages:

```ruby
class FailedPaymentConsumer
  include Hutch::Consumer
  consume 'gc.ps.payment.failed'
  arguments 'x-max-length' => 10
end
```

This sets the `x-max-length` header. For more details, see the [RabbitMQ
documentation on Queue Length Limit](https://www.rabbitmq.com/maxlength.html). To find out more
about custom queue arguments, consult the [RabbitMQ documentation on AMQP Protocol Extensions](https://www.rabbitmq.com/extensions.html).

Consumers can write to Hutch's log by calling the logger method. The logger method returns
a [Logger object](http://ruby-doc.org/stdlib-2.1.2/libdoc/logger/rdoc/Logger.html).

```ruby
class FailedPaymentConsumer
  include Hutch::Consumer
  consume 'gc.ps.payment.failed'

  def process(message)
    logger.info "Marking payment #{message[:id]} as failed"
    mark_payment_as_failed(message[:id])
  end
end
```

If you are using Hutch with Rails and want to make Hutch log to the Rails
logger rather than `stdout`, add this to `config/initializers/hutch.rb`

```ruby
Hutch::Logging.logger = Rails.logger
```

A logger can be set for the client by adding this config before calling `Hutch.connect`

```ruby
client_logger = Logger.new("/path/to/bunny.log")
Hutch::Config.set(:client_logger, client_logger)
```

See this [RabbitMQ tutorial on topic exchanges](http://www.rabbitmq.com/tutorials/tutorial-five-ruby.html)
to learn more.

### Message Processing Tracers

Tracers allow you to track message processing.

This will enable NewRelic custom instrumentation:

```ruby
Hutch::Config.set(:tracer, Hutch::Tracers::NewRelic)
```

And this will enable Datadog custom instrumentation:

```ruby
Hutch::Config.set(:tracer, Hutch::Tracers::Datadog)
```

Batteries included!

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

If you're using the new Zeitwerk autoloader (enabled by default in Rails 6)
and the consumers are not loaded in development environment you will need to
trigger the autoloading in an initializer with

```ruby
::Zeitwerk::Loader.eager_load_all
```

or with something more specific like

```ruby
autoloader = Rails.autoloaders.main

Dir.glob(File.join('app/consumers', '*_consumer.rb')).each do |consumer|
  autoloader.preload(consumer)
end
```

### Consumer Groups

It is possible to load only a subset of consumers. This is done by defining a consumer
group under the `consumer_groups` configuration key:

``` yaml
consumer_groups:
  payments:
    - DepositConsumer
    - CashoutConsumer
  notification:
    - EmailNotificationConsumer
```

To only load a group of consumers, use the `--only-group` option:

``` shell
hutch --only-group=payments --config=/path/to/hutch.yaml
```

### Loading Consumers Manually (One-by-One)

To require files that define consumers manually, simply pass each file as an
option to `--require`. Hutch will automatically detect whether you've provided
a Rails app or a standard file, and take the appropriate behaviour:

```bash
# loads a rails app
hutch --require path/to/rails-app
# loads a ruby file
hutch --require path/to/file.rb
```

### Stopping Hutch

Hutch supports graceful stops. That means that if done correctly, Hutch will wait for your consumer to finish processing before exiting.

To gracefully stop your workers, you may send the following signals to your Hutch processes: `INT`, `TERM`, or `QUIT`.

```bash
kill -SIGINT 123 # or kill -2 123
kill -SIGTERM 456 # or kill -15 456
kill -SIGQUIT 789 # or kill -3 789
```

![](http://g.recordit.co/wyCdzG9Kh3.gif)

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

If using publisher confirms with amqp gem, see [this issue](https://github.com/ruby-amqp/amqp/issues/92)
and [this gist](https://gist.github.com/3042381) for more info.

## Configuration

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
 * `mq_tls_ca_certificates`: array of paths to CA keys (if not specified to Hutch, will default to Bunny defaults which are system-dependent)
 * `mq_verify_peer`: should SSL certificate be verified? (default: `true`)
 * `require_paths`: array of paths to require
 * `autoload_rails`: should Hutch command line runner try to automatically load Rails environment files?
 * `daemonise`: should Hutch runner process daemonise?
 * `pidfile`: path to PID file the runner should use
 * `channel_prefetch`: basic.qos prefetch value to use (default: `0`, no limit). See Bunny and RabbitMQ documentation.
 * `publisher_confirms`: enables publisher confirms. Leaves it up to the app how they are
                         tracked (e.g. using `Hutch::Broker#confirm_select` callback or `Hutch::Broker#wait_for_confirms`)
 * `force_publisher_confirms`: enables publisher confirms, forces `Hutch::Broker#wait_for_confirms` for every publish. **This is the safest option which also offers the lowest throughput**.
 * `log_level`: log level used by the standard Ruby logger (default: `Logger::INFO`)
 * `error_handlers`: a list of error handler objects, see classes in `Hutch::ErrorHandlers`. All configured
   handlers will be invoked unconditionally in the order listed.
 * `error_acknowledgements`: a chain of responsibility of objects that acknowledge/reject/requeue messages when an
    exception happens, see classes in `Hutch::Acknowledgements`.
 * `mq_exchange`: exchange to use for publishing (default: `hutch`)
 * `heartbeat`: [RabbitMQ heartbeat timeout](http://rabbitmq.com/heartbeats.html) (default: `30`)
 * `connection_timeout`: Bunny's socket open timeout (default: `11`)
 * `read_timeout`: Bunny's socket read timeout (default: `11`)
 * `write_timeout`: Bunny's socket write timeout (default: `11`)
 * `automatically_recover`: Bunny's enable/disable network recovery (default: `true`)
 * `network_recovery_interval`: Bunny's reconnect interval (default: `1`)
 * `tracer`: tracer to use to track message processing
 * `namespace`: A namespace string to help group your queues (default: `nil`)

### Environment variables

The file configuration options mentioned above can also be passed in via environment variables, using the `HUTCH_` prefix, eg.

 * `connection_timeout` &rarr; `HUTCH_CONNECTION_TIMEOUT`.

### Configuration precedence

In order from lowest to highest precedence:

0. Default values
0. `HUTCH_*` environment variables
0. Configuration file
0. Explicit settings through `Hutch::Config.set`

### Generated list of configuration options

Generate with

0. `yard doc lib/hutch/config.rb`
0. Copy the _Configuration_ section from `doc/Hutch/Config.html` here, with the anchor tags stripped.

<table border="1" class="settings" style="overflow:visible;">
  <thead>
    <tr>
      <th>
        Setting name
      </th>
      <th>
        Default value
      </th>
      <th>
        Type
      </th>
      <th>
        ENV variable
      </th>
      <th>
        Description
      </th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><tt>mq_host</tt></td>
      <td>127.0.0.1</td>
      <td>String</td>
      <td><tt>HUTCH_MQ_HOST</tt></td>
      <td><p>RabbitMQ hostname</p></td>
    </tr>
    <tr>
      <td><tt>mq_exchange</tt></td>
      <td>hutch</td>
      <td>String</td>
      <td><tt>HUTCH_MQ_EXCHANGE</tt></td>
      <td><p>RabbitMQ Exchange to use for publishing</p></td>
    </tr>
    <tr>
      <td><tt>mq_exchange_type</tt></td>
      <td>topic</td>
      <td>String</td>
      <td><tt>HUTCH_MQ_EXCHANGE_TYPE</tt></td>
      <td><p>RabbitMQ Exchange type to use for publishing</p></td>
    </tr>
    <tr>
      <td><tt>mq_vhost</tt></td>
      <td>/</td>
      <td>String</td>
      <td><tt>HUTCH_MQ_VHOST</tt></td>
      <td><p>RabbitMQ vhost to use</p></td>
    </tr>
    <tr>
      <td><tt>mq_username</tt></td>
      <td>guest</td>
      <td>String</td>
      <td><tt>HUTCH_MQ_USERNAME</tt></td>
      <td><p>RabbitMQ username to use.</p></td>
    </tr>
    <tr>
      <td><tt>mq_password</tt></td>
      <td>guest</td>
      <td>String</td>
      <td><tt>HUTCH_MQ_PASSWORD</tt></td>
      <td><p>RabbitMQ password</p></td>
    </tr>
    <tr>
      <td><tt>uri</tt></td>
      <td>nil</td>
      <td>String</td>
      <td><tt>HUTCH_URI</tt></td>
      <td><p>RabbitMQ URI (takes precedence over MQ username, password, host, port and vhost settings)</p></td>
    </tr>
    <tr>
      <td><tt>mq_api_host</tt></td>
      <td>127.0.0.1</td>
      <td>String</td>
      <td><tt>HUTCH_MQ_API_HOST</tt></td>
      <td><p>RabbitMQ HTTP API hostname</p></td>
    </tr>
    <tr>
      <td><tt>mq_port</tt></td>
      <td>5672</td>
      <td>Number</td>
      <td><tt>HUTCH_MQ_PORT</tt></td>
      <td><p>RabbitMQ port</p></td>
    </tr>
    <tr>
      <td><tt>mq_api_port</tt></td>
      <td>15672</td>
      <td>Number</td>
      <td><tt>HUTCH_MQ_API_PORT</tt></td>
      <td><p>RabbitMQ HTTP API port</p></td>
    </tr>
    <tr>
      <td><tt>heartbeat</tt></td>
      <td>30</td>
      <td>Number</td>
      <td><tt>HUTCH_HEARTBEAT</tt></td>
      <td><p><a href="http://rabbitmq.com/heartbeats.html">RabbitMQ heartbeat timeout</a></p></td>
    </tr>
    <tr>
      <td><tt>channel_prefetch</tt></td>
      <td>0</td>
      <td>Number</td>
      <td><tt>HUTCH_CHANNEL_PREFETCH</tt></td>
      <td><p>The <tt>basic.qos</tt> prefetch value to use.</p></td>
    </tr>
    <tr>
      <td><tt>connection_timeout</tt></td>
      <td>11</td>
      <td>Number</td>
      <td><tt>HUTCH_CONNECTION_TIMEOUT</tt></td>
      <td><p>Bunny's socket open timeout</p></td>
    </tr>
    <tr>
      <td><tt>read_timeout</tt></td>
      <td>11</td>
      <td>Number</td>
      <td><tt>HUTCH_READ_TIMEOUT</tt></td>
      <td><p>Bunny's socket read timeout</p></td>
    </tr>
    <tr>
      <td><tt>write_timeout</tt></td>
      <td>11</td>
      <td>Number</td>
      <td><tt>HUTCH_WRITE_TIMEOUT</tt></td>
      <td><p>Bunny's socket write timeout</p></td>
    </tr>
    <tr>
      <td><tt>automatically_recover</tt></td>
      <td>true</td>
      <td>Boolean</td>
      <td><tt>HUTCH_AUTOMATICALLY_RECOVER</tt></td>
      <td><p>Bunny's enable/disable network recovery</p></td>
    </tr>
    <tr>
      <td><tt>network_recovery_interval</tt></td>
      <td>1</td>
      <td>Number</td>
      <td><tt>HUTCH_NETWORK_RECOVERY_INTERVAL</tt></td>
      <td><p>Bunny's reconnect interval</p></td>
    </tr>
    <tr>
      <td><tt>graceful_exit_timeout</tt></td>
      <td>11</td>
      <td>Number</td>
      <td><tt>HUTCH_GRACEFUL_EXIT_TIMEOUT</tt></td>
      <td><p>FIXME: DOCUMENT THIS</p></td>
    </tr>
    <tr>
      <td><tt>consumer_pool_size</tt></td>
      <td>1</td>
      <td>Number</td>
      <td><tt>HUTCH_CONSUMER_POOL_SIZE</tt></td>
      <td><p>Bunny consumer work pool size</p></td>
    </tr>
    <tr>
      <td><tt>mq_tls</tt></td>
      <td>false</td>
      <td>Boolean</td>
      <td><tt>HUTCH_MQ_TLS</tt></td>
      <td><p>Should TLS be used?</p></td>
    </tr>
    <tr>
      <td><tt>mq_verify_peer</tt></td>
      <td>true</td>
      <td>Boolean</td>
      <td><tt>HUTCH_MQ_VERIFY_PEER</tt></td>
      <td><p>Should SSL certificate be verified?</p></td>
    </tr>
    <tr>
      <td><tt>mq_api_ssl</tt></td>
      <td>false</td>
      <td>Boolean</td>
      <td><tt>HUTCH_MQ_API_SSL</tt></td>
      <td><p>Should SSL be used for the RabbitMQ API?</p></td>
    </tr>
    <tr>
      <td><tt>autoload_rails</tt></td>
      <td>true</td>
      <td>Boolean</td>
      <td><tt>HUTCH_AUTOLOAD_RAILS</tt></td>
      <td><p>Should the current Rails app directory be required?</p></td>
    </tr>
    <tr>
      <td><tt>daemonise</tt></td>
      <td>false</td>
      <td>Boolean</td>
      <td><tt>HUTCH_DAEMONISE</tt></td>
      <td><p>Should the Hutch runner process daemonise?</p></td>
    </tr>
    <tr>
      <td><tt>publisher_confirms</tt></td>
      <td>false</td>
      <td>Boolean</td>
      <td><tt>HUTCH_PUBLISHER_CONFIRMS</tt></td>
      <td><p>Should RabbitMQ publisher confirms be enabled?</p></td>
    </tr>
    <tr>
      <td><tt>force_publisher_confirms</tt></td>
      <td>false</td>
      <td>Boolean</td>
      <td><tt>HUTCH_FORCE_PUBLISHER_CONFIRMS</tt></td>
      <td><p>Enables publisher confirms, forces Hutch::Broker#wait_for_confirms for</p></td>
    </tr>
    <tr>
      <td><tt>enable_http_api_use</tt></td>
      <td>true</td>
      <td>Boolean</td>
      <td><tt>HUTCH_ENABLE_HTTP_API_USE</tt></td>
      <td><p>Should the RabbitMQ HTTP API be used?</p></td>
    </tr>
    <tr>
      <td><tt>consumer_pool_abort_on_exception</tt></td>
      <td>false</td>
      <td>Boolean</td>
      <td><tt>HUTCH_CONSUMER_POOL_ABORT_ON_EXCEPTION</tt></td>
      <td><p>Should Bunny's consumer work pool threads abort on exception.</p></td>
    </tr>
    <tr>
      <td><tt>consumer_tag_prefix</tt></td>
      <td>hutch</td>
      <td>String</td>
      <td><tt>HUTCH_CONSUMER_TAG_PREFIX</tt></td>
      <td><p>Prefix displayed on the consumers tags.</p></td>
    </tr>
    <tr>
      <td><tt>namespace</tt></td>
      <td>nil</td>
      <td>String</td>
      <td><tt>HUTCH_NAMESPACE</tt></td>
      <td><p>A namespace to help group your queues</p></td>
    </tr>
    <tr>
      <td><tt>group</tt></td>
      <td>''</td>
      <td>String</td>
      <td><tt>HUTCH_GROUP</tt></td>
      <td></td>
    </tr>
  </tbody>
</table>
