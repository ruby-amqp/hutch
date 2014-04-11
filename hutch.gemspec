require File.expand_path('../lib/hutch/version', __FILE__)

Gem::Specification.new do |gem|
  gem.add_runtime_dependency 'bunny', '~> 1.2.1'
  gem.add_runtime_dependency 'carrot-top', '~> 0.0.7'
  gem.add_runtime_dependency 'multi_json', '~> 1.5'
  gem.add_development_dependency 'rspec', '~> 2.12.0'
  gem.add_development_dependency 'simplecov', '~> 0.7.1'

  gem.name = 'hutch'
  gem.summary = 'Easy inter-service communication using RabbitMQ.'
  gem.description = 'Hutch is a Ruby library for enabling asynchronous ' +
                    'inter-service communication using RabbitMQ.'
  gem.version = Hutch::VERSION.dup
  gem.authors = ['Harry Marr']
  gem.email = ['developers@gocardless.com']
  gem.homepage = 'https://github.com/gocardless/hutch'
  gem.require_paths = ['lib']
  gem.license = 'MIT'
  gem.executables = ['hutch']
  gem.files = `git ls-files`.split("\n")
  gem.test_files = `git ls-files -- spec/*`.split("\n")
end
