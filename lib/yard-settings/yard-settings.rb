YARD::Templates::Engine.register_template_path(File.dirname(__FILE__) + '/../../templates')
require File.join(File.dirname(__FILE__), 'handler') if RUBY19
