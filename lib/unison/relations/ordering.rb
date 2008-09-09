module Unison
  module Relations
    class Ordering < CompositeRelation
      attr_reader :operand, :order_by_attributes
      retain :operand

      subscribe do
        operand.on_insert do |inserted|
          insert(inserted)
        end
      end
      subscribe do
        operand.on_delete do |inserted|
          delete(inserted)
        end
      end
      subscribe do
        operand.on_tuple_update do |tuple, attribute, old_value, new_value|
          reorder_tuples
          tuple_update_subscription_node.call(tuple, attribute, old_value, new_value)
        end
      end

      def initialize(operand, *order_by_attributes)
        super()
        @operand, @order_by_attributes = operand, order_by_attributes
      end

      def merge(tuples)
        raise "Relation must be retained" unless retained?
        operand.merge(tuples)
      end

      def to_arel
        operand.to_arel.order(*order_by_attributes.map {|order_by_attribute| order_by_attribute.to_arel})
      end

      def tuple_class
        operand.tuple_class
      end

      def set
        operand.set
      end

      def composed_sets
        operand.composed_sets
      end

      def inspect
        "<#{self.class}:#{object_id} @operand=#{operand.inspect} @order_by_attributes=#{order_by_attributes.inspect}>"
      end

      protected

      def add_to_tuples(tuple_to_add)
        super
        reorder_tuples
      end

      def reorder_tuples
        tuples.sort!(&comparator)
      end

      def initial_read
        operand.tuples.sort(&comparator)
      end
      
      def comparator
        lambda do |a, b|
          left_side, right_side = [], []
          order_by_attributes.each do |order_by_attribute|
            if order_by_attribute.ascending?
              left_side.push(a[order_by_attribute])
              right_side.push(b[order_by_attribute])
            else
              left_side.push(b[order_by_attribute])
              right_side.push(a[order_by_attribute])
            end
          end
          left_side <=> right_side
        end
      end
    end
  end
end
