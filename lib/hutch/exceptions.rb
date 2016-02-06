module Hutch
  if defined?(JRUBY_VERSION)
    require 'march_hare/exceptions'
    class Exception < MarchHare::Exception; end
  else
    require "bunny/exceptions"
    # Bunny::Exception inherits from StandardError
    class Exception < Bunny::Exception; end
  end
  class ConnectionError < Exception; end
  class AuthenticationError < Exception; end
  class WorkerSetupError < Exception; end
  class PublishError < Exception; end
end
