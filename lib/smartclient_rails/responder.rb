require 'builder'
require 'action_controller'
require 'active_model'

ActionController::Base.class_eval do
private

  # Render a global error message in a format understand by isc
  def render_error_msg_to_isc msg
    xml = Builder::XmlMarkup.new :indent => 2
    xml.instruct! :xml, :version => '1.0', :encoding => 'UTF-8'
    xml.response do
      xml.status -1
      xml.data msg
    end
    render :xml => xml.target!
  end
end

ActionController::Responder.class_eval do
  # Add a responder strategy for to_isc. Note that you can supply a :to_isc option to the respond_with
  # call that will then be used for all of the to_isc calls (which themselves default to to_xml behaviour,
  # unless you've done something else in your models).
  def to_isc
    # First we do try to render a template ...
    default_render
  rescue ActionView::MissingTemplate => e
    # If no template, we'll do the default thing here
    render_isc
  end

  # This is a standard rendering for smartclient, assuming that the resource is an ActiveRelation
  # or Array (for fetch) or an ActiveModel (for the others).
  def render_isc
    xml = Builder::XmlMarkup.new :indent => 2
    xml.instruct! :xml, :version => '1.0', :encoding => 'UTF-8'

    # We'll work with the SmartClient operationType here ...
    case controller.isc_metadata[:operationType]
      when "add", "remove", "update"
        xml.response do
          if resource.errors.empty?
            xml.status 0
            xml.data do
              xml << resource.to_isc(options[:to_isc] || {})
            end
          else
            xml.status -4
            xml << resource.errors.to_isc
          end
        end

      when "fetch"
        # For fetches, we expect to be responding with an ActiveRelation that represents the
        # whole universe of potential matches -- not yet paginated, since we may as well
        # just do the pagination here. In fact, it probably does not need to be an ActiveRelation,
        # as long as it response to :count, :each, :limit, :offset and :to_isc like ActiveRecord does.
        xml.response do
          # For fetches, if we get this far, the status is always good ...
          xml.status 0
          # We count the total rows from the ActiveRelation
          resource_count = resource.count # We cache it ...
          xml.totalRows resource_count
          # We get a reference to the resource, because we're going to want to add some filters ...
          filtered_resource = resource
          # Apply the start row if present ... note the deliberate assignment in the if statement
          if start_row = controller.isc_metadata[:startRow].to_i
            xml.startRow start_row
            filtered_resource = filtered_resource.offset(start_row)
          end
          # Apply the end row if present ... again, the assignment is deliberate in the if statement
          # Note that the semantics of startRow and endRow are as follows:
          # -- both are zero based
          # -- the startRow is included in the result set
          # -- the endRow is *not* included in the result set
          # So, the "typical" startRow of 0 and endRow of 75 means to return the first 75 records
          if end_row = controller.isc_metadata[:endRow].to_i
            end_row = [end_row, resource_count].min
            xml.endRow end_row
            filtered_resource = filtered_resource.limit(end_row - start_row)
          end
          xml.data do
            filtered_resource.each do |record|
              xml << record.to_isc(options[:to_isc])
            end
          end
        end
      else raise "Did not understand operationType #{controller.metadata[:operationType]}"
    end

    render :xml => xml.target!
  end
end

# Some array additions that let us treat it like an ActiveRelation, if we're careful
class Array
  # Returns an array beginning at the offset
  def offset start
    slice(start .. -1)
  end

  # Returns an array truncated at this length
  def limit number
    slice(0, number)
  end
end

ActiveModel::Serialization.class_eval do
  # We rely on to_xml in ActiveModel to do the heavy-lifting, but we
  # supply some default options here. You can affect the options either
  # by passing them in as :to_isc options in the :respond_with call in
  # the controller, or by implementing :to_isc in the models.
  def to_isc options={}
    to_xml({
      :skip_instruct => true,
      :skip_types => true,
      :root => "record",
      :dasherize => false
    }.merge(options || {})) do |xml|
      yield xml if block_given?
    end
  end
end

ActiveModel::Errors.class_eval do
  # Defines :to_isc on ActiveModel::Errors, so that we can render errors
  # in a way that SmartClient will recognize.
  def to_isc
    ret = {}
    each do |attr, msg|
      ret[attr] ||= []
      ret[attr] << msg
    end
    ret.each_pair do |key, value|
      ret[key] = value.join(", ")
    end
    ret.to_xml({
      :skip_instruct => true,
      :skip_types => true,
      :root => "errors",
      :dasherize => false
    })
  end
end
