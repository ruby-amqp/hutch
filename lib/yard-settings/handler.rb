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

    (hutch_config[collection_name] ||= []) << { name: name }
  rescue => e
    require "pry"
    binding.pry
  end
end

# class RSpecItHandler < YARD::Handlers::Ruby::Base
#   handles method_call(:it)

#   def process
#     return if owner.nil?
#     obj = P(owner[:spec])
#     return if obj.is_a?(Proxy)

#     (obj[:specifications] ||= []) << {
#       name: statement.parameters.first.jump(:string_content).source,
#       file: statement.file,
#       line: statement.line,
#       source: statement.last.last.source.chomp
#     }
#   end
# end
