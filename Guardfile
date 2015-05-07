guard :rspec, :cmd => 'bundle exec rspec --color --format doc' do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$}) { |m| "spec/#{m[1]}_spec.rb" }
  watch('lib/hutch/channel_broker.rb') { ' spec/lib/hutch/broker.rb' }
  watch('spec/spec_helper.rb') { 'spec' }
end
