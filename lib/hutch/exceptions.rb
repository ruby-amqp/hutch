module Hutch
  class ConnectionError < StandardError; end
  class AuthenticationError < StandardError; end
  class WorkerSetupError < StandardError; end
end
