def build_consumer
  @consumer_inc ||= "0"
  @consumer_inc = @consumer_inc.next
  double('Consumer',
         routing_keys: %w( a b c ),
         get_queue_name: 'consumer' + @consumer_inc,
         get_arguments: {},
         get_serializer: nil)
end

def build_queue
  instance_double('Bunny::Queue')
end
