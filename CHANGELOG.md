## 1.3.2 (in development)

No changes yet.

## 1.3.1 (Dec 11, 2024)

### Rails 8.x Compatibility

Contributed by @drobny.

GitHub issue: [#404](https://github.com/ruby-amqp/hutch/pull/404)


## 1.3.0 (Nov 11, 2024)

### Ruby 3.2 Compatibility

GitHub issue: [#392](https://github.com/ruby-amqp/hutch/pull/392)

### Relaxed ActiveSupport Dependency Constraints

Contributed by @drobny.

GitHub issue: [#402](https://github.com/ruby-amqp/hutch/pull/402)

### Client-Provided Connection Name

Contributed by @sharshenov.

GitHub issue: [#399](https://github.com/ruby-amqp/hutch/pull/399)


## 1.1.1 (March 18th, 2022)

### Dependency Bump

Hutch now allows ActiveSupport 7.x.


## 1.1.0 (July 26th, 2021)

### Bugsnag Error Handler

Contributed by @ivanhuang1.

GitHub issue: [#362](https://github.com/ruby-amqp/hutch/pull/362)

### Datadog Tracer

Contributed by Karol @Azdaroth Galanciak.

GitHub issue: [#360](https://github.com/ruby-amqp/hutch/pull/360)

### Updated Sentry Error Handler

Contributed by Karol @Azdaroth Galanciak.

GitHub issue: [#363](https://github.com/ruby-amqp/hutch/pull/363)

### Type Casting for Values Set Using Hutch::Config.set

Values set with `Hutch::Config.set` now have expected setting type casting
applied to them.

Contributed by Karol @Azdaroth Galanciak.

GitHub issue: [#358](https://github.com/ruby-amqp/hutch/pull/358)

### Wider MultiJson Adoption

Contributed by Ulysse @BuonOmo Buonomo.

GitHub issue: [#356](https://github.com/ruby-amqp/hutch/pull/356)

### README Corrections

Contributed by Johan @johankok Kok.

GitHub issue: [#353](https://github.com/ruby-amqp/hutch/pull/353)

## 1.0.0 (April 8th, 2020)

Hutch has been around for several years. It is time to ship a 1.0. With it we try to correct
a few of overly opinionated decisions from recent releases. This means this release
contains potentially breaking changes.

### Breaking Changes

 * Hutch will no longer configure any queue type (such as [quorum queues](https://www.rabbitmq.com/quorum-queues.html))
   or queue mode (used by classic [lazy queues](https://www.rabbitmq.com/lazy-queues.html))
   by default as that can be breaking change for existing Hutch and RabbitMQ installations due to the
   [property equivalence requirement](https://www.rabbitmq.com/queues.html#property-equivalence) in AMQP 0-9-1.

   This means **some defaults introduced in `0.28.0` ([gocardless/hutch#341](https://github.com/gocardless/hutch/pull/341)) were reverted**.
   The user has to opt in to configure the queue type and mode and other [optional arguments](https://www.rabbitmq.com/queues.html#optional-arguments) they need to use.
   Most optional arguments can be set via [policies](https://www.rabbitmq.com/parameters.html#policies) which is always the recommended approach. 
   Queue type, unfortunately, is not one of them as different queue types have completely different
   implementation details, on disk data formats and so on.

   To use a quorum queue, use the `quorum_queue` consumer DSL method:

   ``` ruby
   class ConsumerUsingQuorumQueue
      include Hutch::Consumer
      consume 'hutch.test1'
      # when in doubt, prefer using a policy to this DSL
      # https://www.rabbitmq.com/parameters.html#policies
      arguments 'x-key': :value
        
      quorum_queue
   end
   ```

   To use a classic lazy queue, use the `lazy_queue` consumer DSL method:

   ``` ruby
   class ConsumerUsingLazyQueue
     include Hutch::Consumer
     consume 'hutch.test1'
     # when in doubt, prefer using a policy to this DSL
      # https://www.rabbitmq.com/parameters.html#policies
      arguments 'x-key': :value
     
     lazy_queue
     classic_queue
   end
   ```

   By default Hutch will not configure any `x-queue-type` or `x-queue-mode` optional arguments
   which is identical to RabbitMQ defaults (a regular classic queue).

   Note that as of RabbitMQ 3.8.2, an omitted `x-queue-type` is [considered to be identical](https://github.com/rabbitmq/rabbitmq-common/issues/341)
   to `x-queue-type` set to `classic` by RabbitMQ server.


   #### Enhancements

    * Exchange type is now configurable via the `mq_exchange_type` config setting. Supported exchanges must be
      compatible with topic exchanges (e.g. wrap it). Default value is `topic`.

      This feature is limited to topic and delayed message exchange plugins and is mostly
      useful for forward compatibility.

      Contributed by Michael Bumann.

      GitHub issue: [gocardless/hutch#349](https://github.com/gocardless/hutch/pull/349)


## 0.28.0 (March 17, 2020)

### Enhancements

  * Add lazy and quorum options for queues.

    GitHub issue: [gocardless/hutch#341](https://github.com/gocardless/hutch/pull/341)

    Contributed by: Arthur Del Esposte

  * Log level in the message publisher switched to DEBUG.

    GitHub issue: [gocardless/hutch#343](https://github.com/gocardless/hutch/pull/343)

    Contributed by: Codruț Constantin Gușoi

### Documentation

  * Add zeitwerk note to README.

    GitHub issue: [gocardless/hutch#342](https://github.com/gocardless/hutch/pull/342)

    Contributed by: Paolo Zaccagnini

### CI

  * Use jruby-9.2.9.0

    GitHub issue: [gocardless/hutch#336](https://github.com/gocardless/hutch/pull/336)

    Contributed by: Olle Jonsson

## 0.27.0 (September 9th, 2019)

### Enhancements

 * Error handler for Rollback.

   GitHub issue: [gocardless/hutch#332](https://github.com/gocardless/hutch/pull/332)

   Contributed by Johan Kok.

### Bug Fixes

 * Allow for the latest ActiveSupport version.

   GitHub issue: [gocardless/hutch#334](https://github.com/gocardless/hutch/pull/334)

 * Signal tests are now skipped on JRuby.

   Contributed by Olle Jonsson.

   GitHub issue: [gocardless/hutch#326](https://github.com/gocardless/hutch/pull/326)

### Dependency Bumps

Bunny and other dependencies were updated to their latest release
series.


## 0.26.0 (February 13th, 2019)

### Dependency Bumps

Bunny and other dependencies were updated to their latest release
series.

### Synchronized Connection Code

The methods that connect to RabbitMQ are now synchronized which makes
them safer to use in concurrent settings. Note that Hutch still
uses a single Bunny channel which is not meant to be shared
between threads without application-level synchronization for publishing.

Contributed by Chris Barton.

GitHub issue: [#308](https://github.com/gocardless/hutch/pull/308).

### More Bunny Options Propagated

Contributed by Damian Le Nouaille.

GitHub issue: [#322](https://github.com/gocardless/hutch/pull/322).

### Removed Opbeat Integration

The service is no longer generally available.

Contributed by Olle Jonsson.

GitHub issue: [#313](https://github.com/gocardless/hutch/pull/313)


## 0.25.0 - January 17th, 2018

### Consumer groups

Consumer groups allow you to run groups of consumers together, rather than running them
all at once in a single process. You define groups in your config file, and then specify
a `--only-group` option when starting up Hutch with `hutch`.

Contributed by Nickolai Smirnov.

GitHub pull request: [#296](https://github.com/gocardless/hutch/pull/296)

### Fix configuring Hutch with a URI

When Hutch is configured to connect to RabbitMQ with a URI, we should respect the
`amqps` specification, defaulting to the standard protocol ports when not specified.

This means, for example, that `amqp://guest:guest@127.0.0.1/` connects to the server on
port 5672 and does not use TLS, whereas `amqps://guest:guest@127.0.0.1/` connects to the
server on port 5671 and uses TLS.

This behaviour was introduced in [#159](https://github.com/gocardless/hutch/pull/159) but
broken since then. This fixes it, and includes tests.

Contributed by Michael Canden-Lennox.

GitHub pull request: [#305](https://github.com/gocardless/hutch/pull/305)

### Pass exceptions when setting up the client to configured error handlers

When an error occurs during Hutch's startup, it is currently not passed to the configured
error handlers. This starts handling those exceptions.

Contributed by Valentin Krasontovitsch.

GitHub issue: [#288](https://github.com/gocardless/hutch/issues/288)
GitHub pull request: [#301](https://github.com/gocardless/hutch/pull/301)

### Log the Rails environment when running Hutch in verbose mode

When starting up Hutch in verbose mode with `hutch -v`, the Rails environment is now
logged.

Contributed by [@wppurking](https://github.com/wppurking).

GitHub pull request: [#282](https://github.com/gocardless/hutch/pull/282)

### Make the Honeybadger error handler compatible with new versions of `honeybadger-ruby`

[`honeybadger-ruby`](https://github.com/honeybadger-io/honeybadger-ruby/)
[changed](https://github.com/honeybadger-io/honeybadger-ruby/blob/master/CHANGELOG.md#300---2017-02-06)
its API in v3.0.0. This updates our error handler to work with that, whilst still
maintaining our existing behaviour.

Contributed by Olle Jonsson and Bill Ruddock.

GitHub pull requests: [#274](https://github.com/gocardless/hutch/pull/274),
[#290](https://github.com/gocardless/hutch/pull/290)

## 0.24.0 — February 1st, 2017

### Configurable Consumer Prefixes

Hutch consumers now can use user-provided prefixes for consumer tags.

Contributed by Dávid Lantos.

GitHub issue: [#265](https://github.com/gocardless/hutch/pull/265)

### Signal Handling in Workers

Hutch will now handle several OS signals:

 * `USR2` will log stack traces of all alive VM threads
 * `QUIT` (except on JRuby), `INT`, `TERM` will cause Hutch daemon to shut down

 Contributed by Olle Jonsson.

GitHub issues: [#263](https://github.com/gocardless/hutch/pull/263), [#271](https://github.com/gocardless/hutch/pull/271)

### Opbeat Tracer

Hutch now provides a tracer implementation for [Opbeat](https://opbeat.com/).

Contributed by Olle Jonsson.

GitHub issue: [#262](https://github.com/gocardless/hutch/pull/262)

### `HUTCH_URI` Support

The `HUTCH_URI` environment variable now can be used to configure
Hutch connection URI.

Contributed by Sam Stickland.

GitHub issue: [#270](https://github.com/gocardless/hutch/pull/270)


## 0.23.1 — October 20th, 2016

This release contains a **breaking change** in the error
handlers interface.

### All Message Properties Passed to Error Handlers

Previously error handlers were provided a message ID as first
argument to `ErrorHandler#handle`. Now it is a hash of all message
properties.

This is a **breaking public API change**. If you do not use custom
error handlers, you are not affected.

Contributed by Pierre-Louis Gottfrois.

GH issue: [hutch#238](https://github.com/gocardless/hutch/pull/238)

### Opbeat Error Handler

Contributed by Olle Jonsson.


## 0.22.1 — June 7th, 2016

### Message Payload is Reported to Sentry

Contributed by Matt Thompson.

### Daemonization Flag Ignored on JRuby

Hutch will no longer try to daemonize its process on JRuby
(since it is not supported) and will emit a warning instead.

Contributed by Olle Jonsson.

### Custom Setup Steps in Hutch::Worker

`Hutch::Worker` now accepts a list of callables that are invoked
after queue setup.

Contributed by Kelly Stannard.

### More Flexible and Better Abstracted Hutch::Broker

`Hutch::Broker` was refactored with some bits extracted into separate
classes or methods, making them easier to override.

Contributed by Aleksandar Ivanov and Ryan Hosford.

### Configurable Consumer Thread Pool Exception Handling (MRI only)

`:consumer_pool_abort_on_exception` is a new option
(defaults to `false`) which defines whether Bunny's
consumer work pool threads should abort on exception.
The option is ignored on JRuby.

Contributed by Seamus Abshere.

### Worker: Log received messages using level DEBUG instead of INFO

Received messages used to be logged using severity level INFO.
This has been lowered to DEBUG.

Contributed by Jesper Josefsson.

### Refactoring

Olle Jonsson and Kelly Stannard have contributed
multiple internal improvements that have no behaviour changes.


## 0.21.0 — February 7th, 2016

### JRuby Compatibility Restored

Contributed by Jesper Josefsson.

### More Reliable Rails app Detection

Rails application detection now won't produce false positives
for applications that include `config/environment.rb`. Instead,
`bin/rails` and `script/rails` are used.

Contributed by @bisusubedi.

### Refactoring

Contributed by Jesper Josefsson and Olle Jonsson.


## 0.20.0 — November 16th, 2015

### Hutch::Exception includes Bunny::Exception

`Hutch::Exception` now inherits from `Bunny::Exception` which
inherits from `StandardError`.

GH issue: [#137](https://github.com/gocardless/hutch/issues/137).


### Pluggable (Negative) Acknowledge Handlers

Hutch now can be configured to use a user-provided
object(s) to perform acknowledgement on consumer exceptions.

For example, this is what the default handler looks like:

``` ruby
require 'hutch/logging'
require 'hutch/acknowledgements/base'

module Hutch
  module Acknowledgements
    class NackOnAllFailures < Base
      include Logging

      def handle(delivery_info, properties, broker, ex)
        prefix = "message(#{properties.message_id || '-'}): "
        logger.debug "#{prefix} nacking message"

        broker.nack(delivery_info.delivery_tag)

        # terminates further chain processing
        true
      end
    end
  end
end
```

Handlers are configured similarly to exception notification handlers,
via `:error_acknowledgements` in Hutch config.

Contributed by Derek Kastner.

GH issue: [#177](https://github.com/gocardless/hutch/pull/177).


### Configurable Exchange Properties

`:mq_exchange_options` is a new config option that can be used
to provide a hash of exchange attributes (durable, auto-delete).
The options will be passed directly to Bunny (or March Hare, when
running on JRuby).

Contributed by Derek Kastner.

GH issue: [#170](https://github.com/gocardless/hutch/pull/170).


### Bunny Update

Bunny is updated to 2.2.1.


## 0.19.0 — September 7th, 2015

### Pluggable Serialisers

Hutch now supports pluggable serialisers: see `Hutch::Serializer::JSON` for
an example. Serialiser is configured via Hutch config as a Ruby
class.

Contributed by Dmitry Galinsky.


### multi_json Update

Hutch now depends on multi_json `1.11.x`.

### Bunny Update

Bunny is updated to [2.2.0](http://blog.rubyrabbitmq.info/blog/2015/09/06/bunny-2-dot-2-0-is-released/).

### More Bunny SSL Options

`:mq_tls_ca_certificates` and `:mq_verify_peer` options will now be passed on to Bunny as `:tls_ca_certificates` and `:verify_peer` respectively.

Contributed by Kennon Ballou.

## 0.18.0 — August 16th, 2015

### JRuby Support (Using March Hare)

Hutch will now use March Hare when running on JRuby.
This will yield significant throughput and core utilisation
improvements for workloads with many and/or busy consumers.

Contributed by Teodor Pripoae.


### Configurable Consumer Thread Pool Size

`:consumer_pool_size` is a new option (defaults to `1`) which defines
Bunny consumer work pool size.

Contributed by Derek Kastner.

### Bunny Logger Option

`:client_logger` is a new option that allows
for configuring loggerd used by Bunny, the underlying
RabbitMQ client library.

Contributed by Nate Salisbury.


## 0.17.0 — July 19th, 2015

Fixes an issue with `NoMethodError` in `Hutch::Config`.


## 0.16.0 — July 19th, 2015

### Support amqps URIs

Hutch now automatically enables TLS and changes default port
when URI scheme is `amqps`.

Contributed by Carl Hörberg.

### Hash With Indifferent Access

Hutch now uses `HashWithIndifferentAccess` internally
to reduce use of symbols (which are not garbage collected
by widely used Ruby versions).

Contributed by Teodor Pripoae.


## 0.15.0 — May 5th, 2015

### Airbrake Error Handler

Contributed by Nate Salisbury.

### Ruby 1.9 Support Dropped

Ruby 1.9 is no longer supported by Hutch (and soon Bunny 2.0).
1.9 is also no longer maintained by the Ruby core team.

### Custom Arguments per Consumers

Allow to set custom arguments per consumers by using the `arguments` setter.
Arguments are usually used by rabbitmq plugins or to set queue policies. You can
find a list of supported arguments [here](https://www.rabbitmq.com/extensions.html).

Contributed by Pierre-Louis Gottfrois.

### Message Processing Tracers

Allow to track message processing by using the `:tracer` config option,
the value should be a class (or fully-qualified string name of a class) that
implements the tracing interface.

A tracer that performs NewRelic instrumentation ships with Hutch
and requires New Relic gem to be loaded.

Contributed by Mirosław Nagaś.

### Added Logger Method to Consumer Module

Consumers can now call a logger method to write to Hutch's log.

Contributed by Matty Courtney

## 0.14.0 — Feb 23rd, 2015

### Configurable Socket Timeouts

Socket read and write timeouts are now configurable using
the `read_timeout` and `write_timeout` options, respectively.

Contributed by Chris Barton.


### Logged Messages as Serialised as JSON

...as opposed to Ruby object printing.

Contributed by Andrew Morton.


### Configurable Heartbeat

Config now supports a new option: `:heartbeat`, which is passed
on to Bunny.

Contributed by Simon Taranto.


### HoneyBadger Error Handler

Contributed by Daniel Farrell.


### Hutch.connected? Now Returns Up-to-Date Value

`Hutch.connected?` no longer relies on an ivar and always returns
an up-to-date value.

Contributed by Pierre-Louis Gottfrois.


## 0.13.0 — Dec 5th, 2014

### HTTP API Can Be Disabled for Consumers

HTTP API use can be disabled for consumers using the `:enable_http_api_use` config
option (defaults to true).



## 0.12.0 — Nov 25th, 2014

### Explicit Requires

Hutch no longer relies on `Kernel#autoload` to load its key
modules and classes.

Contributed by Pierre-Louis Gottfrois.


### hutch --version No Longer Fails

```
hutch --version
```

no longer fails with an exception.

Contributed by Olle Jonsson.


### Base Class for All Hutch Exceptions

All Hutch exceptions now inherit from `Hutch::Exception`.

Contributed by Pierre-Louis Gottfrois.


## 0.11.0 — Nov 14th, 2014

### Publisher Confirms Support

`:force_publisher_confirms` is a new configuration option that forces `Hutch.publish` to wait
for a confirm for every message published. Note that this **will cause a significant drop in throughput**:

``` ruby
Hutch::Config.set(:force_publisher_confirms, true)
```

`Hutch::Broker#confirm_select` and `Hutch::Broker#wait_for_confirms` are new public API methods
that delegate to their respective `Bunny::Channel` counterparts. `Hutch::Broker#confirm_select`
can be used to handle confirms with a callback instead of waiting:

``` ruby
broker.confirm_select do |delivery_tag, multiple, nack|
  # ...
end
```


### Bunny Update

Bunny is updated to [1.6.0](http://blog.rubyrabbitmq.info/blog/2014/10/31/bunny-1-dot-6-0-is-released/).


## 0.10.0 — Oct 22, 2014

### Configuration via URI

Hutch now supports a new configuration key, `:uri`, which allows
connection configuration via a URI.

Note that since the URI has to include credentials, this option
is not available on the command line.

### Bunny Update

Bunny is updated to `1.5.1`, which mitigates the POODLE attack
by disabling SSL 3.0 where possible.

### Payload in Error Handlers

Error handlers will now have access to message payload.

Contributed by Daniel Farrell.

### Exceptions in Error Handlers Don't Prevent Nacks

Exceptions in error handlers no longer prevent messages from being
`basic.nack`-ed.

### Pid File Support

`:pidfile` is a new configuration option that stores Hutch process
PID in a file at provided path.

Contributed by Rustam Sharshenov.

### More Info on Message

Bunny's `delivery_info`, `properties` and payload are now accessible on `Hutch::Message`.

Contributed by gregory.


### Optional Config Parameters

`Hutch::Config` constructor now accepts an extra hash of optional
configuration parameters.

Contributed by Ignazio Mostallino.


## 0.9.0 — May 13, 2014

### Platform-aware Signal Registration

Hutch will no longer attempt to register signal traps
for signals not supported by the environment (e.g. on by certain OSes).

Contributed by Tobias Matthies.

### TLS Fixes

Hutch now properly passes client TLS key and certificate to
Bunny.

Contributed by Eric Nelson.

### Bunny Update

Bunny is updated to 1.2.x which should offer
[much better latency](https://github.com/ruby-amqp/bunny/pull/187) for
workloads with lots of small messages published frequently.

### More Unit Testing Friendly CLI/Runner

`Hutch::CLI#run` now accepts a parameter and is easier to use
in automated tests.


## 0.8.0 — February 13, 2014

### Uncaught Exceptions Result in Rejected Messages

Uncaught exceptions in consumers now result in Hutch rejecting
messages (deliveries) using `basic.nack`. This way they are [dead lettered](http://www.rabbitmq.com/dlx.html).

Contributed by Garrett Johnson.

### Missing Require

`hutch/consumer.rb` no longer fails to load with the
apps that do not `require "set"`.

Contributed by Garrett Johnson.

### Relaxed Queue Namespace Validation

Namespaces now can include any characters that are valid in RabbitMQ
queue names.

Contributed by Garrett Johnson.

### basic.qos Configuration

It is now possible to configure `basic.qos` (aka channel prefetch) setting
used by Hutch using the `:channel_prefetch` config key.

### Passwords No Longer Logged

Hutch now elides passwords from logs.


## 0.7.0 — January 14, 2014

### Optional HTTP API Use

It is now possible to make Hutch [not use RabbitMQ HTTP
API](https://github.com/gocardless/hutch/pull/69) (e.g. when the
RabbitMQ management plugin that provides it is not available).


### Extra Arguments for Hutch::Broker#publish

Extra options [passed to `Hutch::Broker#publish` will now be propagated](https://github.com/gocardless/hutch/pull/61).


### Content-Type for Messages

Messages published with Hutch now have content type set
to `application/json`.


### Greater Heartbeat Interval

Hutch now uses heartbeat interval of 30, so heartbeats won't interfere with transfers
of large messages over high latency networks (e.g. between AWS availability regions).


### Custom Queue Names

It is now possible to [specify an optional queue name](https://github.com/gocardless/hutch/pull/49):

``` ruby
class FailedPaymentConsumer
  include Hutch::Consumer
  consume 'gc.ps.payment.failed'
  queue_name 'failed_payments'

  def process(message)
    mark_payment_as_failed(message[:id])
  end
end
```

### Global Properties for Publishers

[Global properties can now be specified](https://github.com/gocardless/hutch/pull/62) for publishing:

``` ruby
Hutch.global_properties = proc {
  { app_id: 'api', headers: { request_id: RequestId.request_id } }
}
```

## 0.6.0 - November 4, 2013

- Metadata can now be passed in to `#publish`

## 0.5.1 - October 17, 2013

- Raise an exception when publishing fails

## 0.5.0 - October 17, 2013

- Support for the `--mq-tls-key` and `--mq-tls-cert` configuration options.

## 0.4.5 - October 15, 2013

- No exception raised when hutch is run with no consumers. Instead, a warning
  is logged.
- Internal refactoring: use Bunny's shiny `ConsumerWorkPool#threads`
  attr_reader.

## 0.4.4 - October 12, 2013

- Friendlier Message#inspect, doesn't spew out detailed bunny info.

## 0.4.3 - October 11, 2013

- More autoloading tweaks, all internal modules are now autoloaded.

## 0.4.2 - October 11, 2013

- Autoload the Broker module, which was missed in the previous release.

## 0.4.1 - October 11, 2013

- Autoload internal modules. Fixes regression where the `Config` module was
  not available by simply `require`ing `hutch`.

## 0.4.0 - October 9, 2013

- Support for loading configuration from a file, specified with the `--config`
  command line option.

## 0.3.0 - September 24, 2013

- Add `--[no-]autoload-rails` flag to optionally disable the autoloading of
  Rails apps in the current directory

## 0.2.1 - September 17, 2013

- Fix inconsistency with `mq-tls` option

## 0.2.0 - September 16, 2013

- Support for connecting to RabbitMQ with TLS/SSL. There are two new
  configuration options : `mq-tls` and `mq-api-ssl`.
- JSON message parsing errors are now handled properly.

## 0.1.1 - September 9, 2013

- Relax Bunny dependency specification

## 0.1.0 - September 9, 2013

- Initial release
