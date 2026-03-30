require "rails/generators"
require "rails/generators/active_record"
require "rails/generators/migration"

module CodeSunset
  module Generators
    class MigrationGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      def copy_migration
        migration_template "create_code_sunset_tables.rb", "db/migrate/create_code_sunset_tables.rb"
      end

      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end
    end
  end
end
