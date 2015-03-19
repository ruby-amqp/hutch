module Hutch
  class Exception < StandardError; end
  class ConnectionError < Exception; end
  class AuthenticationError < Exception; end
  class WorkerSetupError < Exception; end
  class PublishError < Exception; end
end
