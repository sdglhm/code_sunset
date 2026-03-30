require "rails/generators/base"

module CodeSunset
  module Generators
    class EjectUiGenerator < Rails::Generators::Base
      source_root File.expand_path("../../../..", __dir__)

      UI_FILES = {
        "app/assets/javascripts/code_sunset/application.js" => "app/assets/javascripts/code_sunset/application.js",
        "app/assets/javascripts/code_sunset/vendor/chart.umd.min.js" => "app/assets/javascripts/code_sunset/vendor/chart.umd.min.js",
        "app/helpers/code_sunset/application_helper.rb" => "app/helpers/code_sunset/application_helper.rb",
        "app/views/layouts/code_sunset/application.html.erb" => "app/views/layouts/code_sunset/application.html.erb",
        "app/views/code_sunset/dashboard/index.html.erb" => "app/views/code_sunset/dashboard/index.html.erb",
        "app/views/code_sunset/features/index.html.erb" => "app/views/code_sunset/features/index.html.erb",
        "app/views/code_sunset/features/show.html.erb" => "app/views/code_sunset/features/show.html.erb",
        "app/views/code_sunset/removal_candidates/index.html.erb" => "app/views/code_sunset/removal_candidates/index.html.erb",
        "app/assets/stylesheets/code_sunset/application.css" => "app/assets/stylesheets/code_sunset/application.css"
      }.freeze

      desc "Copies the Code Sunset dashboard UI into the host app for customization."

      def copy_ui_files
        UI_FILES.each do |source, destination|
          copy_file source, destination
        end
      end

      def show_next_steps
        say_status :ejected, "Host app copies now override the engine UI. Customize them freely and mount the engine anywhere you like.", :green
      end
    end
  end
end
