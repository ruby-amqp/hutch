source 'https://rubygems.org'

gemspec

group :development do
  gem "rake"
  gem "guard", "~> 2.14", platform: :mri_23
  gem "guard-rspec", "~> 4.7", platform: :mri_23
end

group :development, :test do
  gem "sentry-raven"
  gem "honeybadger"
  gem "coveralls", "~> 0.8.15", require: false
  gem "newrelic_rpm"
  gem "airbrake", "~> 5.0"
  gem "opbeat", "~> 3.0.9"
end

group :development, :darwin do
  gem "rb-fsevent", "~> 0.9"
  gem "growl", "~> 1.0.3"
end
