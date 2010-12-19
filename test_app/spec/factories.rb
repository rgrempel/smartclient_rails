Factory.sequence(:first_name) {|n| "Ryan#{n}"}
Factory.sequence(:last_name) {|n| "Rempel#{n}"}

Factory.define :person do |p|
  p.first_name {Factory.next :first_name}
  p.last_name {Factory.next :last_name}
end
