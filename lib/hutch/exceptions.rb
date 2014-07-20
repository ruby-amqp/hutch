module Hutch
  class ConnectionError < StandardError; end
  class AuthenticationError < StandardError; end
  class WorkerSetupError < StandardError; end
  class PublishError < StandardError; end
  class Reject < StandardError; end
  class Requeue < StandardError; end
end
