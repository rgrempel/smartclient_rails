require_relative '../spec_helper'

module SmartClientRails
  describe Criteria do
    before(:each) do
      @simple = {
        "first_name" => "ryan"
      }
      @advanced = {
        "_constructor" => "AdvancedCriteria",
        "operator" => "equals",
        "fieldName" => "first_name",
        "value" => "ryan"
      }
    end

    describe :from_params do
      it "should produce a SimpleCriteria when passed a hash" do
        Criteria.from_params(@simple) {Person}.should be_a(Criteria::SimpleCriteria)
      end

      it "should produce an AdvancedCriteria when passed a hash with a _constructor" do
        Criteria.from_params(@advanced) {Person}.should be_a(Criteria::AdvancedCriteria)
      end

      it "should raise error if no block passed" do
        lambda {
          Criteria.from_params(@simple)
        }.should raise_error
      end

      it "should accept JSON for a SimpleCriteria" do
        c = Criteria.from_params(@simple.to_json) {Person}
        c.should be_a(Criteria::SimpleCriteria)
        simple = @simple
        c.instance_eval do
          @criteria.should == simple
        end
      end

      it "should accept JSON for an AdvancedCriteria" do
        c = Criteria.from_params(@advanced.to_json) {Person}
        c.should be_a(Criteria::AdvancedCriteria)
        advanced = @advanced
        advanced.delete("_constructor")
        c.instance_eval do
          @criteria.should == advanced
        end
      end
    end

    describe Criteria::Base do
      describe :get_arel_attribute do
        it "should accept ActiveRecord::Base descendants" do
          criteria = Criteria::Base.new @simple, Proc.new {Person}
          attribute = criteria.get_arel_attribute "first_name"
          attribute.should == Person.arel_table["first_name"]
        end

        it "should accept arel tables" do
          criteria = Criteria::Base.new @simple, Proc.new {Person.arel_table}
          attribute = criteria.get_arel_attribute "first_name"
          attribute.should == Person.arel_table["first_name"]
        end

        it "should accept arel attributes" do
          criteria = Criteria::Base.new @simple, Proc.new {|field_name|
            Person.arel_table[field_name]
          }
          attribute = criteria.get_arel_attribute "first_name"
          attribute.should == Person.arel_table["first_name"]
        end
      end
    end

    describe Criteria::SimpleCriteria do
      it "should handle one-value hash" do
        c = Criteria::SimpleCriteria.new ({
          "_textMatchStyle" => "exact",
          "first_name" => "ryan"
        }), Proc.new {Person}
        Person.where(c.to_arel).to_sql.should == %q{SELECT "people".* FROM "people" WHERE (("people"."first_name" = 'ryan'))}
      end

      it "should handle two-value hash" do
        c = Criteria::SimpleCriteria.new ({
          "_textMatchStyle" => "exact",
          "first_name" => "ryan",
          "id" => "27"
        }), Proc.new {Person}
        Person.where(c.to_arel).to_sql.should == %q{SELECT "people".* FROM "people" WHERE (("people"."first_name" = 'ryan') AND ("people"."id" = 27))}
      end

      it "should handle two-value hash with array" do
        c = Criteria::SimpleCriteria.new ({
          "_textMatchStyle" => "exact",
          "first_name" => ["ryan", "joe"],
          "id" => "27"
        }), Proc.new {Person}
        Person.where(c.to_arel).to_sql.should == %q{SELECT "people".* FROM "people" WHERE (("people"."first_name" = 'ryan' OR "people"."first_name" = 'joe') AND ("people"."id" = 27))}
      end

      it "should use the textMatchStyle substring with text field but not numeric field" do
        c = Criteria::SimpleCriteria.new ({
          "_textMatchStyle" => "substring",
          "first_name" => "ryan",
          "id" => "27"
        }), Proc.new {Person}
        Person.where(c.to_arel).to_sql.should == %q{SELECT "people".* FROM "people" WHERE (("people"."first_name" LIKE '%ryan%') AND ("people"."id" = 27))}
      end

      it "should use the textMatchStyle startsWith with text field but not numeric field" do
        c = Criteria::SimpleCriteria.new ({
          "_textMatchStyle" => "startsWith",
          "first_name" => "ryan",
          "id" => "27"
        }), Proc.new {Person}
        Person.where(c.to_arel).to_sql.should == %q{SELECT "people".* FROM "people" WHERE (("people"."first_name" LIKE 'ryan%') AND ("people"."id" = 27))}
      end
    end

    describe Criteria::AdvancedCriteria do
      # TODO: This actually changes depending on the database (i.e. SQLite vs. Postgres etc.)
      describe "value operators" do
        {
          "equals"         => %q{"people"."first_name" = 'ryan'},
          "notEqual"       => %q{"people"."first_name" != 'ryan'},
          "iEquals"        => %q{"people"."first_name" LIKE 'ryan'},
          "iNotEqual"      => %q{"people"."first_name" NOT LIKE 'ryan'},
          "greaterThan"    => %q{"people"."first_name" > 'ryan'},
          "lessThan"       => %q{"people"."first_name" < 'ryan'},
          "greaterOrEqual" => %q{"people"."first_name" >= 'ryan'},
          "lessOrEqual"    => %q{"people"."first_name" <= 'ryan'},
          "contains"       => %q{"people"."first_name" LIKE '%ryan%'},
          "startsWith"     => %q{"people"."first_name" LIKE 'ryan%'},
          "endsWith"       => %q{"people"."first_name" LIKE '%ryan'},
          "iContains"      => %q{"people"."first_name" LIKE '%ryan%'},
          "iStartsWith"    => %q{"people"."first_name" LIKE 'ryan%'},
          "iEndsWith"      => %q{"people"."first_name" LIKE '%ryan'},
          "notContains"    => %q{"people"."first_name" NOT LIKE '%ryan%'},
          "notStartsWith"  => %q{"people"."first_name" NOT LIKE 'ryan%'},
          "notEndsWith"    => %q{"people"."first_name" NOT LIKE '%ryan'},
          "iNotContains"   => %q{"people"."first_name" NOT LIKE '%ryan%'},
          "iNotStartsWith" => %q{"people"."first_name" NOT LIKE 'ryan%'},
          "iNotEndsWith"   => %q{"people"."first_name" NOT LIKE '%ryan'},
          "iregexp"         => %q{"people"."first_name" REGEXP 'ryan'},
          "regexp"        => %q{regexp_with_case('ryan', "people"."first_name")},
          "isNull"         => %q{"people"."first_name" IS NULL},
          "notNull"        => %q{"people"."first_name" IS NOT NULL},
        }.each_pair do |operator, sql|
          it "should use operator #{operator}" do
            c = Criteria::AdvancedCriteria.new ({
              "operator" => operator,
              "fieldName" => "first_name",
              "value" => "ryan"
            }), Proc.new {Person}
            Person.where(c.to_arel).to_sql.should == %{SELECT "people".* FROM "people" WHERE (#{sql})}
          end
        end
      end

      describe "array operators" do
        {
          "inSet"    => %q{"people"."first_name" IN ('ryan', 'joanne')},
          "notInSet" => %q{"people"."first_name" NOT IN ('ryan', 'joanne')},
        }.each_pair do |operator, sql|
          it "should use operator #{operator}" do
            c = Criteria::AdvancedCriteria.new ({
              "operator" => operator,
              "fieldName" => "first_name",
              "value" => ["ryan", "joanne"]
            }), Proc.new {Person}
            Person.where(c.to_arel).to_sql.should == %{SELECT "people".* FROM "people" WHERE (#{sql})}
          end
        end
      end

      describe "field operators" do
        {
          "equalsField"         => %q{"people"."first_name" = "people"."last_name"},
          "notEqualField"       => %q{"people"."first_name" != "people"."last_name"},
          "greaterThanField"    => %q{"people"."first_name" > "people"."last_name"},
          "lessThanField"       => %q{"people"."first_name" < "people"."last_name"},
          "greaterOrEqualField" => %q{"people"."first_name" >= "people"."last_name"},
          "lessOrEqualField"    => %q{"people"."first_name" <= "people"."last_name"},
        }.each_pair do |operator, sql|
          it "should use operator #{operator}" do
            c = Criteria::AdvancedCriteria.new ({
              "operator" => operator,
              "fieldName" => "first_name",
              "value" => "last_name"
            }), Proc.new {Person}
            Person.where(c.to_arel).to_sql.should == %{SELECT "people".* FROM "people" WHERE (#{sql})}
          end
        end
      end

      describe "range operators" do
        { # TODO ... these need more checking for semantics
          "between"          => %q{"people"."first_name" BETWEEN 'joanne' AND 'ryan'},
          "betweenInclusive" => %q{"people"."first_name" >= 'joanne' AND "people"."first_name" < 'ryan'},
        }.each_pair do |operator, sql|
          it "should use operator #{operator}" do
            c = Criteria::AdvancedCriteria.new ({
              "operator" => operator,
              "fieldName" => "first_name",
              "start" => "joanne",
              "end" => "ryan"
            }), Proc.new {Person}
            Person.where(c.to_arel).to_sql.should == %{SELECT "people".* FROM "people" WHERE (#{sql})}
          end
        end
      end

      describe "logical operators" do
        it "should correctly apply AND to one value" do
          c = Criteria::AdvancedCriteria.new ({
            "operator" => "and",
            "criteria" => [{
              "operator" => "greaterThan",
              "fieldName" => "first_name",
              "value" => "joanne"
            }]
          }), Proc.new {Person}
          sql = %q{"people"."first_name" > 'joanne'}
          Person.where(c.to_arel).to_sql.should == %Q{SELECT "people".* FROM "people" WHERE (#{sql})}
        end

        it "should correctly apply NOT to one value" do
          c = Criteria::AdvancedCriteria.new ({
            "operator" => "not",
            "criteria" => [{
              "operator" => "greaterThan",
              "fieldName" => "first_name",
              "value" => "joanne"
            }]
          }), Proc.new {Person}
          sql = %q{(NOT "people"."first_name" > 'joanne')}
          Person.where(c.to_arel).to_sql.should == %Q{SELECT "people".* FROM "people" WHERE (#{sql})}
        end

        it "should correctly apply AND to two values" do
          c = Criteria::AdvancedCriteria.new ({
            "operator" => "and",
            "criteria" => [{
              "operator" => "greaterThan",
              "fieldName" => "first_name",
              "value" => "joanne"
            },{
              "operator" => "lessThan",
              "fieldName" => "first_name",
              "value" => "ryan"
            }]
          }), Proc.new {Person}
          sql = %q{"people"."first_name" > 'joanne' AND "people"."first_name" < 'ryan'}
          Person.where(c.to_arel).to_sql.should == %Q{SELECT "people".* FROM "people" WHERE (#{sql})}
        end

        it "should correctly apply NOT to two values" do
          c = Criteria::AdvancedCriteria.new ({
            "operator" => "not",
            "criteria" => [{
              "operator" => "greaterThan",
              "fieldName" => "first_name",
              "value" => "joanne"
            },{
              "operator" => "lessThan",
              "fieldName" => "first_name",
              "value" => "ryan"
            }]
          }), Proc.new {Person}
          sql = %q{(NOT ("people"."first_name" > 'joanne' OR "people"."first_name" < 'ryan'))}
          Person.where(c.to_arel).to_sql.should == %Q{SELECT "people".* FROM "people" WHERE (#{sql})}
        end

        it "should correctly apply OR to three values" do
          c = Criteria::AdvancedCriteria.new ({
            "operator" => "or",
            "criteria" => [{
              "operator" => "equals",
              "fieldName" => "first_name",
              "value" => "joanne"
            },{
              "operator" => "equals",
              "fieldName" => "first_name",
              "value" => "ryan"
            },{
              "operator" => "equals",
              "fieldName" => "first_name",
              "value" => "bob"
            }]
          }), Proc.new {Person}
          sql = %q{((("people"."first_name" = 'joanne' OR "people"."first_name" = 'ryan') OR "people"."first_name" = 'bob'))}
          Person.where(c.to_arel).to_sql.should == %{SELECT "people".* FROM "people" WHERE #{sql}}
        end

        it "should correctly apply AND to three values" do
          c = Criteria::AdvancedCriteria.new ({
            "operator" => "and",
            "criteria" => [{
              "operator" => "equals",
              "fieldName" => "first_name",
              "value" => "joanne"
            },{
              "operator" => "equals",
              "fieldName" => "first_name",
              "value" => "ryan"
            },{
              "operator" => "equals",
              "fieldName" => "first_name",
              "value" => "bob"
            }]
          }), Proc.new {Person}
          sql = %q{"people"."first_name" = 'joanne' AND "people"."first_name" = 'ryan' AND "people"."first_name" = 'bob'}
          Person.where(c.to_arel).to_sql.should == %Q{SELECT "people".* FROM "people" WHERE (#{sql})}
        end
      end
    end
  end
end
