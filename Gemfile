source 'https://rubygems.org'

gemspec

group :development do
  gem "rake"
  gem "guard", "~> 0.8.8"
  gem "guard-rspec", "~> 0.5.4"
end

group :development, :test do
  gem "rspec", "~> 3.0"
  gem "coveralls", require: false
  gem "newrelic_rpm"
end

group :development, :darwin do
  gem "rb-fsevent", "~> 0.9"
  gem "growl", "~> 1.0.3"
end
