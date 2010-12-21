require_relative '../spec_helper'

describe ApplicationController do
  # This set up an anoymous subclass ...
  controller do
    def index
      render :nothing => true
    end

    def create
      @test_params = params.dup
      render :nothing => true
    end
  end

  describe(:isc_debug) do
    it "should set the isc_debug variable from params if present" do
      get :index, :isc_debug => "true"
      assert assigns(:isc_debug), "Should have assigned isc_debug to true value"
    end

    it "should not set the isc_debug variable if not present" do
      get :index
      assert !assigns(:isc_debug), "Should not have set isc_debug when param not present"
    end
  end

  it "should set the isc_metadata variable for get" do
    get :index, :_operationType => "fetch",
                :_startRow => "0",
                :_endRow => "75",
                :_textMatchStyle => "substring",
                :_componentId => "isc_PeopleGrid_0",
                :_dataSource => "people",
                :isc_metaDataPrefix => "_",
                :isc_dataFormat => "xml",
                :format => "isc"

    metadata = assigns(:isc_metadata)
    {
      :operationType => "fetch",
      :startRow => "0",
      :endRow => "75",
      :textMatchStyle => "substring",
      :componentId => "isc_PeopleGrid_0",
      :dataSource => "people"
    }.each_pair do |key, value|
      metadata[key].should == value
    end
  end

  describe :sortBy do
    it "should convert sortBy metadata to array if scalar" do
      get :index, :_operationType => "fetch",
                  :_startRow => "0",
                  :_endRow => "75",
                  :isc_metaDataPrefix => "_",
                  :isc_dataFormat => "xml",
                  :_sortBy => "first_name",
                  :format => "isc"

      assigns(:isc_metadata)[:sortBy].should == ["first_name"]
    end

    it "should keep sortBy metadata as array if array" do
      get :index, :_operationType => "fetch",
                  :_startRow => "0",
                  :_endRow => "75",
                  :isc_metaDataPrefix => "_",
                  :isc_dataFormat => "xml",
                  :_sortBy => ["first_name", "last_name"],
                  :format => "isc"

      assigns(:isc_metadata)[:sortBy].should == ["first_name", "last_name"]
    end

    it "should convert sortBy metadata if prefixed with minus sign" do
      get :index, :_operationType => "fetch",
                  :_startRow => "0",
                  :_endRow => "75",
                  :isc_metaDataPrefix => "_",
                  :isc_dataFormat => "xml",
                  :_sortBy => "-first_name",
                  :format => "isc"

      assigns(:isc_metadata)[:sortBy].should == ["first_name DESC"]
    end
  end

  it "should rearrange posts" do
    post :create, :request => {
                    :data => {
                      :session => {
                        :login => "ryan",
                        :password => "password"
                      }
                    },
                    :oldValues => nil,
                    :dataSource => "session",
                    :operationType => "add",
                    :componentId => "isc_LoginForm_0"
                  },
                  :isc_dataFormat => "xml",
                  :format => "isc"

    assigns(:isc_metadata).should == {
      "oldValues" => nil,
      "dataSource" => "session",
      "operationType" => "add",
      "componentId" => "isc_LoginForm_0"
    }

    assigns(:test_params)[:session].should == {
      "login" => "ryan",
      "password" => "password"
    }
  end

  describe(:fetch) do
    controller do
      respond_to :html, :isc

      def index
        respond_with(@person = Person.scoped)
      end
    end

    before(:each) do
      4.times {Factory.create :person}
    end

    it "should use respond_with with :isc format" do
      get :index, :format => "isc",
                  :isc_metaDataPrefix => "_",
                  :_operationType => "fetch",
                  :_startRow => "0",
                  :_endRow => "75"
      response.should be_success
      response.body.should match_xpath("/response/status[text()=0]")
      response.body.should match_xpath("/response/startRow[text()=0]")
      response.body.should match_xpath("/response/endRow[text()=4]")
      response.body.should match_xpath("/response/totalRows[text()=4]")
      response.body.should match_xpath("/response/data/record")
    end
  end
end
