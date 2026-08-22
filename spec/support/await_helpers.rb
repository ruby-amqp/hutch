# Ruby ports of `await_condition/2` and friends from `rabbit_ct_helpers`.
module AwaitHelpers
  class ConditionTimeout < StandardError; end

  POLL_INTERVAL = 0.05

  def await_condition(timeout = 15, label = 'condition')
    deadline = monotonic_now + timeout

    until yield
      raise ConditionTimeout, "#{label} did not materialize in #{timeout}s" if monotonic_now >= deadline

      sleep POLL_INTERVAL
    end
  end

  def await_condition_ignoring_exceptions(timeout = 15, label = 'condition', &condition)
    await_condition(timeout, label) do
      begin
        condition.call
      rescue StandardError
        false
      end
    end
  end

  # Retries a failed expectation, e.g. eventually { expect(queue.message_count).to eq(3) }
  def eventually(poll_interval = 0.2, poll_count = 5)
    yield
  rescue RSpec::Expectations::ExpectationNotMetError, StandardError
    poll_count -= 1
    raise if poll_count.zero?

    sleep poll_interval
    retry
  end

  # Asserts that an expectation keeps holding, e.g. consistently { expect(queue.message_count).to eq(0) }
  def consistently(poll_interval = 0.2, poll_count = 5)
    poll_count.times do
      yield
      sleep poll_interval
    end
  end

  private

  def monotonic_now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
