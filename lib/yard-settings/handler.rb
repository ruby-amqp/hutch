# :nodoc:
class SettingsHandlerBase < YARD::Handlers::Ruby::Base
  handles method_call :string_setting
  handles method_call :number_setting
  handles method_call :boolean_setting

  namespace_only

  def process
    name = statement.parameters.first.jump(:tstring_content, :ident).source
    object = YARD::CodeObjects::MethodObject.new(namespace, name)
    register(object)

    # modify the code object for the new instance method
    object.dynamic = true
    # add custom metadata to the object
    object['custom_field'] = '(Found using method_missing)'

    # Module-level configuration notes
    hutch_config = YARD::CodeObjects::ModuleObject.new(:root, "Hutch::Config")
    collection_name = statement.first.first
    default_value = statement.parameters[1].jump(:tstring_content, :ident).source
    (hutch_config[collection_name] ||= []) << {
      name: name,
      default_value: default_value
    }
  rescue => e
    $stderr.puts e.message, e.inspect
    #require "pry"
    #binding.pry
  end
end
