source 'https://rubygems.org'

ruby '>= 3.0.0'

gemspec

group :development do
  gem "rake"

  gem "yard", "~> 0.9"
  gem 'kramdown', "> 0", platform: :jruby
  gem "redcarpet", "> 0", platform: :mri
  gem "github-markup", "> 0"
end

group :development, :test do
  # activesupport pulls in minitest, and minitest 6 needs prism, a C extension
  # JRuby cannot build (ruby/prism#3959). Nothing here uses minitest.
  gem "minitest", "< 6" if defined?(JRUBY_VERSION)

  gem "rspec", "~> 3.12"
  gem "simplecov", "~> 0.21"

  gem "sentry-ruby"
  gem "honeybadger"
  gem "newrelic_rpm"
  gem "datadog"
  # airbrake-ruby depends on rbtree3, a C extension
  gem "airbrake", "~> 13.0", platform: :mri
  gem "rollbar"
  gem "bugsnag"
end
