source 'https://rubygems.org'

ruby '>= 2.7.0'

gemspec

group :development do
  gem "rake"
  gem "guard", "~> 2.14", platform: :mri
  gem "guard-rspec", "~> 4.7", platform: :mri

  gem "yard", "~> 0.9"
  gem 'kramdown', "> 0", platform: :jruby
  gem "redcarpet", "> 0", platform: :mri
  gem "github-markup", "> 0"
end

group :development, :test do
  gem "rspec", "~> 3.12"
  gem "simplecov", "~> 0.21"

  gem "sentry-raven"
  gem "sentry-ruby"
  gem "honeybadger"
  gem "newrelic_rpm"
  gem "ddtrace", "~> 1.8"
  gem "airbrake", "~> 13.0"
  gem "rollbar"
  gem "bugsnag"
end

group :development, :darwin do
  gem "rb-fsevent", "~> 0.11.2"
  gem "growl", "~> 1.0.3"
end
