require 'rspec/core/rake_task'

desc "Run an IRB session with Hutch pre-loaded"
task :console do
  exec "irb -I lib -r hutch"
end

desc "Run the test suite"
RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = FileList['spec/**/*_spec.rb']
  t.rspec_opts = %w(--color --format doc)
end

task :default => :spec
