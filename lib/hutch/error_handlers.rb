module Hutch
  module ErrorHandlers
    autoload :Logger, 'hutch/error_handlers/logger'
    autoload :Sentry, 'hutch/error_handlers/sentry'
  end
end
