module Hutch
  module ErrorHandlers
    autoload :Logger,      'hutch/error_handlers/logger'
    autoload :Sentry,      'hutch/error_handlers/sentry'
    autoload :Honeybadger, 'hutch/error_handlers/honeybadger'
    autoload :Airbrake,    'hutch/error_handlers/airbrake'
  end
end
