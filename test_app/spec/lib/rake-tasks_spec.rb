require_relative '../spec_helper'

describe "copy javasript" do
  it "should copy the RailsDataSource.js file" do
    file = Rails.root.join('public', 'javascripts', 'RailsDataSource.js')
    file.unlink if file.exist?
    file.exist?.should == false

    system "rake smartclient_rails:copy_javascript"

    file.exist?.should == true
  end
end
