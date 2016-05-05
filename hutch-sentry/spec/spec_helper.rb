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

# set logger to be a null logger
Hutch::Logging.logger = Logger.new(File::NULL)
