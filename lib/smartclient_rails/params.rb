require 'action_controller'

# Register :isc as a type
Mime::Type.register_alias "application/xml", :isc

ActionController::Base.class_eval do
  before_filter :check_isc_debug, :check_isc_metadata
  attr_reader :isc_debug, :isc_metadata

private

  # Check whether the isc_debug parameter has been set. If so,
  # create a variable to track it. This could used by the layout
  # to include the "source" javascript rather than the compressed,
  # minified etc. versions. Controllers could also use it for other
  # purposes.
  def check_isc_debug
    @isc_debug = params.delete(:isc_debug)
    true
  end

  # Massage the isc_metadata
  def check_isc_metadata
    if params[:format] == "isc"
      @isc_metadata = HashWithIndifferentAccess.new
      check_isc_get_requests
      check_isc_put_and_post_requests
    end
    true
  end

  # For the sake of convenience, collect all the isc metatdata into
  # a single hash, and we strip the isc_metaDataPrefix.
  # We also convert sortBy so that the "minus" sign in front turns into
  # a DESC at the end, and multiple sort values are converted properly.
  # Note that you have to apply the sortBy yourself in the controller.
  # You don't need to deal with startRow and endRow, since that will
  # be handled in the responder.
  # We also store isc_dataFormat in the metadaa as dataFormat
  def check_isc_get_requests
    # The prefix will exist if this is a get request (and perhaps delete ...)
    prefix = params.delete(:isc_metaDataPrefix)
    if prefix
      # Note that the dataFormat could be json ... haven't dealt with that
      # case yet.
      @isc_metadata[:dataFormat] = params.delete(:isc_dataFormat)
      prefix_length = prefix.length
      params.delete_if do |key, value|
        string_key = key.to_s
        if string_key.start_with? prefix
          real_key = string_key[prefix_length..-1].to_sym
          if real_key == :sortBy
            value = [value].flatten
            value = value.map {|v| v.gsub(/^-(.*)/, '\1 DESC')}
          end
          @isc_metadata[real_key] = value
          true
        else
          false
        end
      end
    end
  end

  # For put and post requests, we collected metadata and massage the params
  # to match what Rails conventions expect
  # A post request from SmartClient looks like this (for a dataSource with
  # an ID of "session". Note that you should name your dataSource ID's with
  # the singular form, in order to match the way that Rails expects parameters
  # to :create and :update to be named.
  #
  # <request>
  #   <data>
  #     <session>
  #       <login>ryan</login>
  #       <password>password</password>
  #     </session>
  #   </data>
  #   <oldValues/>
  #   <dataSource>session</dataSource>
  #   <operationType>add</operationType>
  #   <componentId>isc_LoginForm_0</componentId>
  # </request>
  #
  # So, we'll pull out the stuff in <data> and put that directly into params ...
  # that will match the Rails convention. Then, we'll store the rest in @isc_metadata
  # Note that isc_dataFormat seems to be sent with all SmartClient requests, so I'm
  # using that as a trigger here. So, given the above, we would end up with
  #
  # params = {
  #   :session => {
  #     :login => "ryan",
  #     :password => "password"
  #   }
  # }
  #
  # and
  #
  # @isc_metadata = {
  #   :oldValues => nil,
  #   :dataSource => "session",
  #   :operationType => "add",
  #   :componentId => "isc_LoginForm_0"
  # }
  #
  def check_isc_put_and_post_requests
    if params[:isc_dataFormat] && params[:request]
      data = params[:request].delete(:data)
      params.merge!(data) if data
      @isc_metadata.merge!(params.delete(:request))
    end
  end
end
