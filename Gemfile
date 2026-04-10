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
  gem "rspec", "~> 3.12"
  gem "simplecov", "~> 0.21"

  gem "sentry-ruby"
  gem "honeybadger"
  gem "newrelic_rpm"
  gem "datadog"
  gem "airbrake", "~> 13.0"
  gem "rollbar"
  gem "bugsnag"
end
