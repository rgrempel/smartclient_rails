require 'arel'

module Arel
  module Predications
    def matches_with_case other
      Nodes::MatchesWithCase.new self, other
    end

    def matches_any_with_case others
      grouping_any :matches_with_case, others
    end

    def matches_all_with_case others
      grouping_all :matches_with_case, others
    end

    def does_not_match_with_case other
      Nodes::DoesNotMatchWithCase.new self, other
    end

    def does_not_match_any_with_case others
      grouping_any :does_not_match_with_case, others
    end

    def does_not_match_all_with_case others
      grouping_all :does_not_match_with_case, others
    end
  end

  module Nodes
    class MatchesWithCase < Arel::Nodes::Binary
    end

    class DoesNotMatchWithCase < Arel::Nodes::Binary
    end
  end

  module Visitors
    class ToSql
      def visit_Arel_Nodes_MatchesWithCase o
        "#{visit o.left} LIKE #{visit o.right}"
      end

      def visit_Arel_Nodes_DoesNotMatchWithCase o
        "#{visit o.left} NOT LIKE #{visit o.right}"
      end
    end

    class MySql
      def visit_Arel_Nodes_MatchesWithCase o
        "BINARY #{visit o.left} LIKE #{visit o.right}"
      end

      def visit_Arel_Nodes_DoesNotMatchWithCase o
        "BINARY #{visit o.left} NOT LIKE #{visit o.right}"
      end
    end
  end
end
