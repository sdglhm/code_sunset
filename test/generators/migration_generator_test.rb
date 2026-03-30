require "test_helper"
require "rails/generators/test_case"
require_relative "../../lib/generators/code_sunset/migration/migration_generator"

module CodeSunset
  class MigrationGeneratorTest < Rails::Generators::TestCase
    tests CodeSunset::Generators::MigrationGenerator
    destination File.expand_path("../tmp/migration", __dir__)

    setup :prepare_destination

    test "creates the migration without requiring a name argument" do
      run_generator

      migrations = Dir[File.join(destination_root, "db/migrate/*_create_code_sunset_tables.rb")]

      assert_equal 1, migrations.size
    end
  end
end
