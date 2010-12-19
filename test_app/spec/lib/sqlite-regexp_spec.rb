require_relative '../spec_helper'

describe "SQLite regexp" do
  before(:each) do
    Factory.create :person, :first_name => "Ryan", :last_name => "Rempel"
    Factory.create :person, :first_name => "ryan", :last_name => "Rempel"
    Factory.create :person, :first_name => "Joanne", :last_name => "Epp"
  end

  describe :regexp do
    it "should not be case sensitive" do
      people = Person.where("first_name REGEXP ?", "ry.n")
      people.count.should == 2
    end
  end

  describe :regexp_with_case do
    it "should be case sensitive" do
      people = Person.where("regexp_with_case(?, first_name)", "ry.n")
      people.count.should == 1
    end
  end
end
