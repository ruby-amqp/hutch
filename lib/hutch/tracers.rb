module Hutch
  module Tracers
    autoload :NullTracer, 'hutch/tracers/null_tracer'

    TRACERS = {
    }

    def self.[](key)
      TRACERS[key] || Hutch::Tracers::NullTracer
    end
  end
end
