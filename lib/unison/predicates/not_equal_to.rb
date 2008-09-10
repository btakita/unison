module Unison
  module Predicates
    class NotEqualTo < BinaryPredicate
      def to_arel
        Arel::Inequality.new(operand_1.to_arel, operand_2.to_arel)
      end

      protected
      def apply(value_1, value_2)
        value_1 != value_2
      end
    end
  end
end