require 'spec_helper'

# Channel recovery is bunny-only, see MarchHareAdapter#install_channel_recovery
return if defined?(JRUBY_VERSION)
require 'hutch/broker'
require 'hutch/worker'
require 'hutch/consumer'
require 'bunny'
require 'json'
require 'securerandom'
require 'timeout'

describe 'channel recovery after delivery acknowledgement timeout', rabbitmq: true, adapter: :bunny do
  CONSUMER_TIMEOUT_MS = 5_000
  # A 4.3 quorum queue times the consumer out on its own timer, which fires at
  # the deadline. Earlier series detect it from the channel tick instead, and
  # `channel_tick_interval` defaults to 60s, so detection lags by up to that much.
  BLOCKED_HANDLER_SECONDS = 20
  BLOCKED_HANDLER_SECONDS_BEFORE_4_3 = 100

  let(:log) { StringIO.new }
  let(:logger) { Logger.new(log) }
  let(:exchange_name) { "hutch.integration.exchange.#{SecureRandom.hex(4)}" }
  let(:queue_name) { "hutch.integration.queue.#{SecureRandom.hex(4)}" }
  let(:routing_key) { "hutch.integration.key.#{SecureRandom.hex(4)}" }

  let(:processed) { [] }
  let(:processed_lock) { Mutex.new }
  let(:timed_out_once) { [false] }

  let(:server_version) do
    Gem::Version.new(publisher.server_properties['version'].to_s[/\A\d+(\.\d+)*/])
  end

  let(:blocked_handler_seconds) do
    if server_version >= Gem::Version.new('4.3')
      BLOCKED_HANDLER_SECONDS
    else
      BLOCKED_HANDLER_SECONDS_BEFORE_4_3
    end
  end

  let(:consumer_class) do
    msgs = processed
    lock = processed_lock
    rk = routing_key
    qn = queue_name
    timed_out = timed_out_once
    blocked = blocked_handler_seconds

    Class.new do
      include Hutch::Consumer

      consume rk
      queue_name qn
      arguments(
        'x-queue-type' => 'quorum',
        'x-consumer-timeout' => CONSUMER_TIMEOUT_MS
      )

      # Both `CONSUMER_TIMEOUT_MS` and this sleep run from the same delivery,
      # so the margin between them does not shrink on a loaded machine.
      define_method(:process) do |message|
        if message['id'] == 'trigger-timeout' && !timed_out[0]
          timed_out[0] = true
          sleep blocked
        end

        lock.synchronize { msgs << message['id'] }
      end
    end
  end

  let(:broker) { Hutch::Broker.new }
  let(:worker) { Hutch::Worker.new(broker, [consumer_class], []) }

  let(:publisher) do
    Bunny.new(
      host: Hutch::Config[:mq_host],
      port: Hutch::Config[:mq_port],
      username: Hutch::Config[:mq_username],
      password: Hutch::Config[:mq_password],
      vhost: Hutch::Config[:mq_vhost]
    ).tap(&:start)
  end

  let(:publisher_channel) { publisher.create_channel }
  let(:exchange) { publisher_channel.topic(exchange_name, durable: true) }

  before do
    Hutch::Logging.logger = logger
    Hutch::Config.set(:mq_exchange, exchange_name)
    Hutch::Config.set(:force_publisher_confirms, false)
    Hutch::Config.set(:client_logger, logger)
  end

  after do
    publisher_channel.close rescue nil
    publisher.close rescue nil
    broker.disconnect rescue nil
    Hutch::Logging.logger = Logger.new(File::NULL)
  end

  def wait_for(timeout, label)
    Timeout.timeout(timeout) do
      loop do
        return true if yield
        sleep 0.25
      end
    end
  rescue Timeout::Error
    raise <<~MSG
      Timed out waiting for: #{label}

      processed_messages=#{processed_messages.inspect}
      channel_open=#{broker.channel.open? rescue 'unknown'}
      channel_closed=#{broker.channel.closed? rescue 'unknown'}

      log output:
      #{log_output}
    MSG
  end

  def processed_messages
    processed_lock.synchronize { processed.dup }
  end

  def log_output
    log.rewind
    log.read
  end

  def publish_message(id)
    exchange.publish(
      JSON.dump('id' => id),
      routing_key: routing_key,
      content_type: 'application/json',
      persistent: true
    )
  end

  # RabbitMQ up to 4.2 closes the channel on a delivery acknowledgement
  # timeout; 4.3+ quorum queues instead cancel only the timed out consumer.
  let(:recovery_log_pattern) do
    /delivery acknowledgement on channel \d+ timed out|cancelled by the server, re-subscribing/i
  end

  # This spec is intentionally slow because RabbitMQ enforces delivery
  # acknowledgement timeouts periodically on a timer, not immediately at the deadline.
  it 're-subscribes and consumes later messages after RabbitMQ times out an unacknowledged delivery' do
    broker.connect
    worker.setup_queues

    publish_message('trigger-timeout')

    wait_for(240, 'a delivery acknowledgement timeout to close the channel or cancel the consumer') do
      log_output.match?(recovery_log_pattern)
    end

    publish_message('after-recovery')

    wait_for(90, 'after-recovery message consumption') do
      processed_messages.include?('after-recovery')
    end

    expect(log_output).to match(recovery_log_pattern)
    expect(processed_messages).to include('after-recovery')
  end
end
