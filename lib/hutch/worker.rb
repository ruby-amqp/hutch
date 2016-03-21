require 'hutch'

=begin
Hutch::Worker is the minimum needed to run a Hutch process.

Usage:
Hutch::Worker.new.run
=end

module Hutch
  class Worker
    def run
      start
      MainLoop.loop_until_signaled
      stop
    end

    private

    def start
      Hutch.connect
      Config[:setup_procs].each(&:call)
    end

    def stop
      Hutch.broker.stop
    end
  end
end
