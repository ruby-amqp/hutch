module Hutch
  module ErrorHandlers
    autoload :Logger,      'hutch/error_handlers/logger'
    autoload :Sentry,      'hutch/error_handlers/sentry'
    autoload :SentryRaven, 'hutch/error_handlers/sentry_raven'
    autoload :Honeybadger, 'hutch/error_handlers/honeybadger'
    autoload :Airbrake,    'hutch/error_handlers/airbrake'
    autoload :Rollbar,     'hutch/error_handlers/rollbar'
    autoload :Bugsnag,     'hutch/error_handlers/bugsnag'
  end
end
