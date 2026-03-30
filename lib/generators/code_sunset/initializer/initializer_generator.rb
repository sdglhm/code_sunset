require "rails/generators/base"

module CodeSunset
  module Generators
    class InitializerGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def copy_initializer
        template "code_sunset.rb", "config/initializers/code_sunset.rb"
      end
    end
  end
end
