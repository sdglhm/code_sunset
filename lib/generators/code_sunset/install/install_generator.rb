require "rails/generators/base"

module CodeSunset
  module Generators
    class InstallGenerator < Rails::Generators::Base
      class_option :eject_ui, type: :boolean, default: false, desc: "Copy the engine dashboard layout, views, helper, and stylesheet into the host app."

      def install_initializer
        invoke "code_sunset:initializer"
      end

      def install_migration
        invoke "code_sunset:migration"
      end

      def install_ui
        return unless options[:eject_ui]

        invoke "code_sunset:eject_ui"
      end
    end
  end
end
