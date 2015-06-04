module Hutch
  module Tracers
    autoload :NullTracer, 'hutch/tracers/null_tracer'
    autoload :NewRelic,   'hutch/tracers/newrelic'

    TRACERS = {
      "NewRelic" => Hutch::Tracers::NewRelic
    }

    def self.[](key)
      TRACERS[key] || Hutch::Tracers::NullTracer
    end
  end
end
