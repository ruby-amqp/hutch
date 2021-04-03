module Hutch
  module Tracers
    autoload :NullTracer, 'hutch/tracers/null_tracer'
    autoload :NewRelic,   'hutch/tracers/newrelic'
    autoload :Datadog,    'hutch/tracers/datadog'
  end
end
