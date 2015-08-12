if defined?(JRUBY_VERSION)
  require 'hutch/adapters/march_hare'
  module Hutch
    Adapter = Adapters::MarchHareAdapter
  end
else
  require 'hutch/adapters/bunny'
  module Hutch
    Adapter = Adapters::BunnyAdapter
  end
end
