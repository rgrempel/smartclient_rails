# This converts the SmartClient SimpleCriteria or AdvancedCriteria to something that
# works with ActiveRecord via Arel. The params are the criteria params as you pass
# them from SmartClient.
#
# You must also provide a block that, when yielded field names as known to SmartClient
# returns the Arel attribute that corresponds. In the simplest case, you can just
# return a Class that descends from ActiveRecord, and we'll assume that it is a field
# on the table for that class. But you can also return an Arel table, or an Arel attribute.
# Note that you are responsible for setting up whatever joins are actually needed to make
# this work.

module SmartClientRails
  module Criteria
    def self.from_params params={}, &arel_proc
      params = {} if params.nil?
      criteria = params.is_a?(String) ? ActiveSupport::JSON.decode(params) : params
      if criteria.delete("_constructor") == "AdvancedCriteria"
        AdvancedCriteria.new criteria, arel_proc
      else
        SimpleCriteria.new criteria, arel_proc
      end
    end

    class Base
      def initialize criteria, arel_proc
        raise "You must supply a block for converting from field names to Arel fields" unless arel_proc
        @criteria = criteria
        @arel_proc = arel_proc
      end

      def get_arel_attribute field_name
        arel = @arel_proc.call(field_name)
        if arel.respond_to?(:arel_table)
          arel.arel_table[field_name]
        elsif arel.respond_to?(:relation)
          arel
        else
          arel[field_name]
        end
      end
    end

    class SimpleCriteria < Base
      def initialize criteria, arel_proc
        super
        @text_match_style = @criteria.delete("_textMatchStyle")
        case @text_match_style
          when "substring", nil
            @operator = :matches_any
            @transform_value = lambda {|c| "%#{c}%"}
          when "exact"
            @operator = :eq_any
            @transform_value = lambda {|c| c}
          when "startsWith"
            @operator = :matches_any
            @transform_value = lambda {|c| "#{c}%"}
          else raise "Did not recognize _textMatchStyle #{@text_match_style}"
        end
      end

      def to_arel
        @criteria.reduce(nil) do |arel, kv|
          attribute = get_arel_attribute(kv[0])
          value = kv[1]
          condition = case attribute.column.type
            when :text, :string
              attribute.send(@operator, [value].flatten.map {|v| @transform_value.call(v)})
            else attribute.eq_any([value].flatten)
          end
          arel.nil? ? condition : arel.and(condition)
        end
      end
    end

    class AdvancedCriteria < Base
      # Criteria hashes will have the following structure:
      #
      #   operator:    One of the many comparison operators, or logical operators.
      #   criteria:    If the operator is "and", "or" or "not", an array of criteria.
      #   fieldName:   The field name that the operator applies to (if not a logical operator)
      #   value:       The value related to teh fieldName ... has various formats depending on the operator
      #   start, end:  For operators that take ranges
      #
      # The logical operators "and" and "or" have the usual meanings. The logical
      # operator "not" is a little different ... it takes an array of criteria, and
      # is true if all the sub-criteria are false. So, if the sub-criteria are
      # represented as a, b and c, the meaning of the "not" operator is equivalent to:
      #
      #   not a and not b and not c
      #
      # or, to put it another way
      #
      #   not (a or b or c)
      def initialize criteria, arel_proc
        super
        @criteria = criteria
      end

      SMARTCLIENT_OPERATORS = {
        "equals"              => {:op => :eq},
        "notEqual"            => {:op => :not_eq},
        "iEquals"             => {:op => :matches},
        "iNotEqual"           => {:op => :does_not_match},
        "greaterThan"         => {:op => :gt},
        "lessThan"            => {:op => :lt},
        "greaterOrEqual"      => {:op => :gteq},
        "lessOrEqual"         => {:op => :lteq},
        "contains"            => {:op => :matches_with_case, :value => :contains},
        "startsWith"          => {:op => :matches_with_case, :value => :startsWith},
        "endsWith"            => {:op => :matches_with_case, :value => :endsWith},
        "iContains"           => {:op => :matches, :value => :contains},
        "iStartsWith"         => {:op => :matches, :value => :startsWith},
        "iEndsWith"           => {:op => :matches, :value => :endsWith},
        "notContains"         => {:op => :does_not_match_with_case, :value => :contains},
        "notStartsWith"       => {:op => :does_not_match_with_case, :value => :startsWith},
        "notEndsWith"         => {:op => :does_not_match_with_case, :value => :endsWith},
        "iNotContains"        => {:op => :does_not_match, :value => :contains},
        "iNotStartsWith"      => {:op => :does_not_match, :value => :startsWith},
        "iNotEndsWith"        => {:op => :does_not_match, :value => :endsWith},
        "regexp"              => {:op => :matches_regexp_with_case},
        "iregexp"             => {:op => :matches_regexp},
        "isNull"              => {:op => :eq, :value => :null},
        "notNull"             => {:op => :not_eq, :value => :null},
        "inSet"               => {:op => :in},
        "notInSet"            => {:op => :not_in},
        "equalsField"         => {:op => :eq, :value => :fieldName},
        "notEqualField"       => {:op => :not_eq, :value => :fieldName},
        "greaterThanField"    => {:op => :gt, :value => :fieldName},
        "lessThanField"       => {:op => :lt, :value => :fieldName},
        "greaterOrEqualField" => {:op => :gteq, :value => :fieldName},
        "lessOrEqualField"    => {:op => :lteq, :value => :fieldName},
  #     "containsField"       => {:op => :matches_with_case, :value => :fieldNameContains},
  #     "startsWithField"     => {:op => :matches_with_case, :value => :fieldNameStartsWith},
  #     "endsWithField"       => {:op => :matches_with_case, :value => :fieldNameEndsWith},
        "between"             => {:op => :in, :value => :exclusiveRange},
        "betweenInclusive"    => {:op => :in, :value => :inclusiveRange}
      }

      # This converts a single criterion to arel. It recurses to deal with sub-criteria.
      def criterion_to_arel criterion
        if ["and", "or"].include? criterion["operator"]
          criterion["criteria"].reduce(nil) do |arel, subcriterion|
            condition = criterion_to_arel(subcriterion)
            arel.nil? ? condition : arel.send(criterion["operator"], condition)
          end
        elsif criterion["operator"] == "not"
          # The SmartClient "not" is the equivalent of the logical negation
          # of OR'ing the children. So, we run the "or" first, and then
          # slip in the logical negation at the end.
          criterion["criteria"].reduce(nil) {|arel, subcriterion|
            condition = criterion_to_arel(subcriterion)
            arel.nil? ? condition : arel.send("or", condition)
          }.not
        elsif SMARTCLIENT_OPERATORS.has_key? criterion["operator"]
          operator = SMARTCLIENT_OPERATORS[criterion["operator"]]
          attribute = get_arel_attribute(criterion["fieldName"])
          value = case operator[:value]
            when :contains;        "%#{criterion["value"]}%"
            when :startsWith;      "#{criterion["value"]}%"
            when :endsWith;        "%#{criterion["value"]}"
            when :null;            nil
            when :fieldName;       get_arel_attribute(criterion["value"])
            when :exclusiveRange;  criterion["start"]..criterion["end"]
            when :inclusiveRange;  criterion["start"]...criterion["end"]
            when :containsField;   raise "unimplemented"
            when :startsWithField; raise "unimplemented"
            when :endsWithField;   raise "unimplemented"
            else                   criterion["value"]
          end
          attribute.send operator[:op], value
        else
          raise "Did not recognize operator #{criterion["operator"]}"
        end
      end

      def to_arel
        criterion_to_arel @criteria
      end
    end
  end
end

module Arel
  module Nodes
    class Node
      def not
        Nodes::Grouping.new Nodes::Not.new(self)
      end
    end
  end
end
