require_relative 'lib/hutch/version'

Gem::Specification.new do |gem|
  if defined?(JRUBY_VERSION)
    gem.platform = 'java'
    gem.add_runtime_dependency 'march_hare', '>= 4.7.0'
  else
    gem.platform = Gem::Platform::RUBY
    gem.add_runtime_dependency 'bunny', '>= 3.1', '< 4.0'
  end
  gem.add_runtime_dependency 'carrot-top', '~> 0.0.7'
  gem.add_runtime_dependency 'activesupport', '>= 4.2'

  gem.name = 'hutch'
  gem.summary = 'Opinionated asynchronous inter-service communication using RabbitMQ'
  gem.description = 'Hutch is a Ruby library for enabling asynchronous inter-service communication using RabbitMQ'
  gem.version = Hutch::VERSION.dup
  gem.required_ruby_version = '>= 3.0'
  gem.authors = ['Harry Marr', 'Michael Klishin']
  gem.homepage = 'https://github.com/ruby-amqp/hutch'
  gem.require_paths = ['lib']
  gem.license = 'MIT'
  gem.executables = ['hutch']
  gem.files = Dir.glob('{lib,bin,templates}/**/*') + %w[README.md LICENSE CHANGELOG.md]
  gem.test_files = Dir.glob('spec/**/*_spec.rb')
end
