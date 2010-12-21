require 'nokogiri'

RSpec::Matchers.define :match_xpath do |xpath|
  match do |body|
    !Nokogiri::XML(body).xpath(xpath).empty?
  end

  failure_message_for_should do |body|
    "expected to find xpath '#{xpath}' in:\n#{body}"
  end

  failure_message_for_should_not do |body|
    "expected not to find xpath '#{xpath}' in:\n#{body}"
  end

  description do
    "match xpath '#{xpath}'"
  end
end
