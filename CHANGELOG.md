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

