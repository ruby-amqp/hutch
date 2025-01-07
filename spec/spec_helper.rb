require 'simplecov'
if ENV['TRAVIS']
  require 'coveralls'
  SimpleCov.formatter = Coveralls::SimpleCov::Formatter
end

SimpleCov.start do
  add_filter '/spec/'
  add_filter '/.bundle/'
end

require 'raven'
require 'hutch'
require 'logger'
require 'ostruct'

# set logger to be a null logger
Hutch::Logging.logger = Logger.new(File::NULL)

RSpec.configure do |config|
  config.raise_errors_for_deprecations!

  if defined?(JRUBY_VERSION)
    config.filter_run_excluding adapter: :bunny
  else
    config.filter_run_excluding adapter: :march_hare
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end

# Constants (classes, etc) defined within a block passed to this method
# will be removed from the global namespace after the block as run.
def isolate_constants
  existing_constants = Object.constants
  yield
ensure
  (Object.constants - existing_constants).each do |constant|
    Object.send(:remove_const, constant)
  end
end
