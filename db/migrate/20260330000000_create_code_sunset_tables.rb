class CreateCodeSunsetTables < ActiveRecord::Migration[7.1]
  def change
    create_table :code_sunset_features do |t|
      t.string :key, null: false
      t.string :owner
      t.text :description
      t.string :status
      t.integer :sunset_after_days, null: false, default: 90
      t.integer :remove_after_days_unused, null: false, default: 60
      t.timestamps
    end

    add_index :code_sunset_features, :key, unique: true
    add_index :code_sunset_features, :status

    create_table :code_sunset_events do |t|
      t.string :feature_key, null: false
      t.datetime :occurred_at, null: false
      t.bigint :user_id
      t.bigint :org_id
      t.string :hashed_user_id
      t.string :hashed_org_id
      t.string :request_id
      t.string :source
      t.string :request_path
      t.string :controller
      t.string :action
      t.string :job_class
      t.string :app_env
      t.string :app_version
      t.string :plan
      t.boolean :internal_org
      t.boolean :paid_org
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :code_sunset_events, :feature_key
    add_index :code_sunset_events, :occurred_at
    add_index :code_sunset_events, [:feature_key, :occurred_at]
    add_index :code_sunset_events, :user_id
    add_index :code_sunset_events, :org_id
    add_index :code_sunset_events, :hashed_user_id
    add_index :code_sunset_events, :hashed_org_id
    add_index :code_sunset_events, :app_env
    add_index :code_sunset_events, :plan
    add_index :code_sunset_events, :metadata, using: :gin

    create_table :code_sunset_daily_rollups do |t|
      t.string :feature_key, null: false
      t.date :day, null: false
      t.integer :hits_count, null: false, default: 0
      t.integer :unique_users_count, null: false, default: 0
      t.integer :unique_orgs_count, null: false, default: 0
      t.datetime :last_seen_at
      t.timestamps
    end

    add_index :code_sunset_daily_rollups, [:feature_key, :day], unique: true
    add_index :code_sunset_daily_rollups, :day
  end
end
