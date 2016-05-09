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

    # Modify the code object for the new instance method
    object.dynamic = true
    # Add custom metadata to the object
    object['custom_field'] = '(Found using method_missing)'

    # Module-level configuration notes
    hutch_config = YARD::CodeObjects::ModuleObject.new(:root, "Hutch::Config")
    collection_name = statement.first.first
    default_value = statement.parameters[1].jump(:tstring_content, :ident).source

    (hutch_config['setting_rows'] ||= []) << {
      name: name,
      default_value: default_value,
      type: collection_name.sub('_setting', '').capitalize,
      description: object.docstring,
      first_line_of_description: first_line_of_description(object)
    }
  end

  def first_line_of_description(object)
    return '' if object.docstring.blank?

    object.docstring.lines.first
  end
end
