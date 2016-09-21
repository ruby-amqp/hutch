require File.expand_path('../lib/hutch/version', __FILE__)

Gem::Specification.new do |gem|
  if defined?(JRUBY_VERSION)
    gem.platform = 'java'
    gem.add_runtime_dependency 'march_hare', '>= 2.16.0'
  else
    gem.platform = Gem::Platform::RUBY
    gem.add_runtime_dependency 'bunny', '>= 2.5.0'
  end
  gem.add_runtime_dependency 'carrot-top', '~> 0.0.7'
  gem.add_runtime_dependency 'multi_json', '~> 1.12.1'
  gem.add_runtime_dependency 'activesupport', (RUBY_VERSION >= '2.3' ? '>= 4.0' : '~> 4.0')
  gem.add_development_dependency 'rspec', '~> 3.0'
  gem.add_development_dependency 'simplecov', '~> 0.12'
  gem.add_development_dependency 'yard', '~> 0.9'

  if defined?(JRUBY_VERSION)
    gem.add_development_dependency 'kramdown', '> 0'
  else
    gem.add_development_dependency 'redcarpet', '> 0'
  end
  gem.add_development_dependency 'github-markup', '> 0'

  gem.name = 'hutch'
  gem.summary = 'Easy inter-service communication using RabbitMQ.'
  gem.description = 'Hutch is a Ruby library for enabling asynchronous ' +
                    'inter-service communication using RabbitMQ.'
  gem.version = Hutch::VERSION.dup
  gem.required_ruby_version = '>= 2.0'
  gem.authors = ['Harry Marr']
  gem.email = ['developers@gocardless.com']
  gem.homepage = 'https://github.com/gocardless/hutch'
  gem.require_paths = ['lib']
  gem.license = 'MIT'
  gem.executables = ['hutch']
  gem.files = `git ls-files`.split("\n")
  gem.test_files = `git ls-files -- spec/*`.split("\n")
end
