source :rubygems

gemspec

group :development do
  gem "rake"
  gem "debugger"
  gem "guard", "~> 0.8.8"
  gem "guard-rspec", "~> 0.5.4"
  gem "sentry-raven", git: "https://github.com/hmarr/raven-ruby.git",
                      branch: 'server-name-fix'
end

group :development, :darwin do
  gem "rb-fsevent", "~> 0.9"
  gem "growl", "~> 1.0.3"
end
