# Instructions for AI Agents

## Overview

Hutch is a Ruby library for enabling asynchronous inter-service communication
using RabbitMQ. It provides a conventions-based framework for consumers and
producers using topic exchanges.

Its key dependencies are [Bunny](https://github.com/ruby-amqp/bunny) (MRI Ruby)
or [March Hare](https://github.com/ruby-amqp/march_hare) (JRuby), two RabbitMQ clients that use AMQP 0-9-1.

On top, Hutch uses [carrot-top](https://github.com/change/carrot-top) for the RabbitMQ HTTP API,
and [ActiveSupport](https://github.com/rails/rails/tree/main/activesupport) from Ruby on Rails.

## Target Ruby Version

This library targets Ruby 3.1 and later versions
For JRuby, the supported series are 9.x and 10.x.

## Build and Test

```bash
bundle install

bundle exec rspec spec
```

To run tests use `rspec` directly (not Rake).

## Key Files

### Core

 * `lib/hutch.rb`: top-level module, global consumer registry, a connection singleton
 * `lib/hutch/broker.rb`: RabbitMQ connection and channel lifecycle, topology declaration, [delivery acknowledgements](https://www.rabbitmq.com/docs/confirms), [publisher confirms](https://www.rabbitmq.com/docs/confirms), [TLS](https://www.rabbitmq.com/docs/ssl), HTTP API client
 * `lib/hutch/worker.rb`: the main consumer loop: topology and consumer setup, delivery dispatch, error handling
 * `lib/hutch/consumer.rb`: `Hutch::Consumer` module included by consumer classes; DSL: `consume`, `queue_name`, `lazy_queue`, `quorum_queue`, `arguments`, `queue_options`, `serializer`
 * `lib/hutch/publisher.rb`: message serialization, routing, publisher confirms
 * `lib/hutch/message.rb`: message wrapper (delivery_info, properties, payload)
 * `lib/hutch/config.rb`: configuration with 3-tier precedence (defaults < ENV `HUTCH_*` < config file < explicit set)
 * `lib/hutch/cli.rb`: CLI (based on `OptionParser`), Rails app detection, consumer loading, daemonization
 * `lib/hutch/exceptions.rb`: `ConnectionError`, `AuthenticationError`, `WorkerSetupError`, `PublishError`
 * `lib/hutch/logging.rb`: configurable logger with `HutchFormatter`
 * `lib/hutch/waiter.rb`: signal handling (`SIGINT`, `SIGTERM`, `SIGQUIT` for shutdown; `SIGUSR2` for thread dumps)
 * `lib/hutch/version.rb`: the `Hutch::VERSION` constant

### Adapters

 * `lib/hutch/adapter.rb`: runtime adapter selector (Bunny on MRI, March Hare on JRuby)
 * `lib/hutch/adapters/bunny.rb`: Bunny adapter
 * `lib/hutch/adapters/march_hare.rb`: March Hare adapter

### Serializers

 * `lib/hutch/serializers/json.rb`: JSON serialization via `multi_json`
 * `lib/hutch/serializers/identity.rb`: pass-through (no-op) serializer

### Error Handlers

 * `lib/hutch/error_handlers/base.rb`: base class
 * `lib/hutch/error_handlers/logger.rb`: logs errors (default)
 * `lib/hutch/error_handlers/sentry.rb`: sentry-ruby integration
 * `lib/hutch/error_handlers/sentry_raven.rb`: legacy sentry-raven integration
 * `lib/hutch/error_handlers/honeybadger.rb`: Honeybadger
 * `lib/hutch/error_handlers/airbrake.rb`: Airbrake
 * `lib/hutch/error_handlers/rollbar.rb`: Rollbar
 * `lib/hutch/error_handlers/bugsnag.rb`: Bugsnag

### Tracers

 * `lib/hutch/tracers/null_tracer.rb`: no-op (default)
 * `lib/hutch/tracers/newrelic.rb`: NewRelic APM
 * `lib/hutch/tracers/datadog.rb`: Datadog tracing

### Acknowledgement Strategies

 * `lib/hutch/acknowledgements/base.rb`: base interface (a chain of responsibility)
 * `lib/hutch/acknowledgements/nack_on_all_failures.rb`: the default fallback

## Test Suite

The test suite uses RSpec:

```bash
bundle exec rspec spec
```

Test files mirror the `lib/hutch/` structure under `spec/hutch/`. Tests are filtered
by adapter at runtime: Bunny specs are excluded on JRuby, March Hare specs on MRI.

## Comments

 * Only add important comments that express the non-obvious intent, both in tests and in the implementation
 * Keep the comments short
 * Pay attention to the grammar of your comments, including punctuation, full stops, articles, and so on

## Change Log

If asked to perform change log updates, consult and modify `CHANGELOG.md` and stick to its
existing writing style.

## Releases

### How to Roll (Produce) a New Release

Suppose the current development version in `CHANGELOG.md` has
a `## X.Y.0 (in development)` section at the top.

To produce a new release:

 1. Update `CHANGELOG.md`: replace `(in development)` with today's date, e.g. `(Mar 30, 2026)`. Make sure all notable changes since the previous release are listed
 2. Update the version in `lib/hutch/version.rb` to match (remove the `.pre` suffix)
 3. Commit with the message `X.Y.0` (just the version number, nothing else)
 4. Tag the commit: `git tag vX.Y.0`
 5. Bump the dev version: add a new `## X.(Y+1).0 (in development)` section to `CHANGELOG.md` with `No changes yet.` underneath, and update `lib/hutch/version.rb` to the next dev version with a `.pre` suffix
 6. Commit with the message `Bump dev version`
 7. Push: `git push && git push origin vX.(Y+1).0`

## Git Instructions

 * Do not commit changes automatically without an explicit permission to do so
 * Never add yourself to the list of commit co-authors
 * Never mention yourself in commit messages in any way (no "Generated by", no AI tool links, etc)

## Style Guide

 * Never add full stops to Markdown list items
