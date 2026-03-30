class HardenCodeSunsetReliability < ActiveRecord::Migration[7.1]
  def change
    add_column :code_sunset_daily_rollups, :app_env, :string
    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE code_sunset_daily_rollups rollups
          SET app_env = matched.app_env
          FROM (
            SELECT feature_key, DATE(occurred_at) AS day, MAX(app_env) AS app_env
            FROM code_sunset_events
            GROUP BY feature_key, DATE(occurred_at)
          ) matched
          WHERE rollups.feature_key = matched.feature_key
            AND rollups.day = matched.day
        SQL

        execute "UPDATE code_sunset_daily_rollups SET app_env = 'unknown' WHERE app_env IS NULL"
      end
    end

    change_column_null :code_sunset_daily_rollups, :app_env, false

    remove_index :code_sunset_daily_rollups, column: [:feature_key, :day]
    add_index :code_sunset_daily_rollups, [:feature_key, :app_env, :day], unique: true, name: "index_code_sunset_rollups_on_feature_env_day"

    create_table :code_sunset_alert_deliveries do |t|
      t.string :feature_key, null: false
      t.string :status, null: false
      t.string :alert_kind, null: false
      t.datetime :delivered_at, null: false
      t.jsonb :payload, null: false, default: {}
      t.timestamps
    end

    add_index :code_sunset_alert_deliveries, [:feature_key, :status, :alert_kind, :delivered_at], name: "index_code_sunset_alerts_on_feature_status_kind_time"
    add_index :code_sunset_alert_deliveries, :delivered_at
  end
end
