require 'arel'
require 'active_record/connection_adapters/sqlite3_adapter'

class ActiveRecord::ConnectionAdapters::SQLite3Adapter
  # This is adapted from http://titusd.co.uk/2010/01/31/regular-expressions-in-sqlite
  # Code by Joe Yates
  def initialize(db, logger, config)
    super

    db.create_function('regexp', 2) do |func, pattern, expression|
      regexp = Regexp.new(pattern.to_s, Regexp::IGNORECASE)
      if expression.to_s.match(regexp)
        func.result = 1
      else
        func.result = 0
      end
    end

    db.create_function('regexp_with_case', 2) do |func, pattern, expression|
      regexp = Regexp.new(pattern.to_s)
      if expression.to_s.match(regexp)
        func.result = 1
      else
        func.result = 0
      end
    end
  end
end

module Arel
  module Predications
    def matches_regexp other
      Nodes::MatchesRegexp.new self, other
    end

    def matches_regexp_with_case other
      Nodes::MatchesRegexpWithCase.new self, other
    end
  end

  module Nodes
    class MatchesRegexp < Arel::Nodes::Binary
    end

    class MatchesRegexpWithCase < Arel::Nodes::Binary
    end
  end

  module Visitors
    class MySql
      def visit_Arel_Nodes_MatchesRegexp o
        "#{visit o.left} REGEXP #{visit o.right}"
      end

      def visit_Arel_Nodes_MatchesRegexpWithCase o
        "BINARY #{visit o.left} REGEXP #{visit o.right}"
      end
    end

    class Oracle
      def visit_Arel_Nodes_MatchesRegexp o
        "REGEXP_LIKE (#{visit o.left}, #{visit o.right}, 'i')"
      end

      def visit_Arel_Nodes_MatchesRegexpWithCase o
        "REGEXP_LIKE (#{visit o.left}, #{visit o.right}, 'c')"
      end
    end

    class PostgreSQL
      def visit_Arel_Nodes_MatchesRegexp o
        "#{visit o.left} ~* #{visit o.right}"
      end

      def visit_Arel_Nodes_MatchesRegexpWithCase o
        "#{visit o.left} ~ #{visit o.right}"
      end
    end

    class SQLite
      def visit_Arel_Nodes_MatchesRegexp o
        "#{visit o.left} REGEXP #{visit o.right}"
      end

      def visit_Arel_Nodes_MatchesRegexpWithCase o
        "regexp_with_case(#{visit o.right}, #{visit o.left})"
      end
    end
  end
end
