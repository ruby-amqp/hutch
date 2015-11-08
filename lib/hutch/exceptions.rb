require "bunny/exceptions"

module Hutch
  # Bunny::Exception inherits from StandardError
  class Exception < Bunny::Exception; end
  class ConnectionError < Exception; end
  class AuthenticationError < Exception; end
  class WorkerSetupError < Exception; end
  class PublishError < Exception; end
end
