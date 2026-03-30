require "test_helper"
require "rails/generators/test_case"
require_relative "../../lib/generators/code_sunset/eject_ui/eject_ui_generator"

module CodeSunset
  class EjectUiGeneratorTest < Rails::Generators::TestCase
    tests CodeSunset::Generators::EjectUiGenerator
    destination File.expand_path("../tmp/eject_ui", __dir__)

    setup :prepare_destination

    test "copies the editable ui files into the host app" do
      run_generator

      assert_file "app/assets/javascripts/code_sunset/application.js"
      assert_file "app/assets/javascripts/code_sunset/vendor/chart.umd.min.js"
      assert_file "app/helpers/code_sunset/application_helper.rb"
      assert_file "app/views/layouts/code_sunset/application.html.erb"
      assert_file "app/views/code_sunset/dashboard/index.html.erb"
      assert_file "app/views/code_sunset/features/index.html.erb"
      assert_file "app/views/code_sunset/features/show.html.erb"
      assert_file "app/views/code_sunset/removal_candidates/index.html.erb"
      assert_file "app/assets/stylesheets/code_sunset/application.css"
    end
  end
end
