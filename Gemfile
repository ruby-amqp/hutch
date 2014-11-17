source 'https://rubygems.org'

gemspec

group :development do
  gem "rake"
  gem "guard", '~> 2.8.1'
  gem "guard-rspec", '~> 4.3.1'
end

group :development, :test do
  gem "sentry-raven"
  gem "coveralls", require: false
  gem 'rb-inotify', '~> 0.9', require: false
end

group :development, :darwin do
  gem "rb-fsevent", "~> 0.9"
  gem "growl", "~> 1.0.3"
end
