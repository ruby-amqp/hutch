module Hutch
  class CLI
    class ConsumersInspector
      def self.format
        new.format
      end

      def format
        consumers = collect_consumers_info
        draw_table(consumers).join("\n")
      end

      def collect_consumers_info
        Hutch.consumers.map do |consumer|
          {
            class: consumer.to_s,
            queue: consumer.get_queue_name,
            route: consumer.routing_keys.to_a.join(', ')
          }
        end
      end

      def draw_table(consumers)
        consumers_table = []
        class_width, queue_width, route_width = widths(consumers)

        consumers_table << "#{'Consumer'.ljust(class_width)} | #{'Queue name'.ljust(queue_width)} | Routing keys"
        consumers_table << '-' * [class_width, queue_width, route_width].sum

        consumers.each do |c|
          consumers_table << "#{c[:class].ljust(class_width)} | #{c[:queue].ljust(queue_width)} | #{c[:route]}"
        end

        consumers_table
      end

      def widths(consumers)
        [consumers.map { |c| c[:class].length }.max || 0,
         consumers.map { |c| c[:queue].length }.max || 0,
         consumers.map { |c| c[:route].length }.max || 0]
      end
    end
  end
end