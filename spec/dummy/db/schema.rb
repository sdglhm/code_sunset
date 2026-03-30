# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_31_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "code_sunset_alert_deliveries", force: :cascade do |t|
    t.string "alert_kind", null: false
    t.datetime "created_at", null: false
    t.datetime "delivered_at", null: false
    t.string "feature_key", null: false
    t.jsonb "payload", default: {}, null: false
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["delivered_at"], name: "index_code_sunset_alert_deliveries_on_delivered_at"
    t.index ["feature_key", "status", "alert_kind", "delivered_at"], name: "index_code_sunset_alerts_on_feature_status_kind_time"
  end

  create_table "code_sunset_daily_rollups", force: :cascade do |t|
    t.string "app_env", null: false
    t.datetime "created_at", null: false
    t.date "day", null: false
    t.string "feature_key", null: false
    t.integer "hits_count", default: 0, null: false
    t.datetime "last_seen_at"
    t.integer "unique_orgs_count", default: 0, null: false
    t.integer "unique_users_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["day"], name: "index_code_sunset_daily_rollups_on_day"
    t.index ["feature_key", "app_env", "day"], name: "index_code_sunset_rollups_on_feature_env_day", unique: true
  end

  create_table "code_sunset_events", force: :cascade do |t|
    t.string "action"
    t.string "app_env"
    t.string "app_version"
    t.string "controller"
    t.datetime "created_at", null: false
    t.string "feature_key", null: false
    t.string "hashed_org_id"
    t.string "hashed_user_id"
    t.boolean "internal_org"
    t.string "job_class"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "occurred_at", null: false
    t.bigint "org_id"
    t.boolean "paid_org"
    t.string "plan"
    t.string "request_id"
    t.string "request_path"
    t.string "source"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["app_env"], name: "index_code_sunset_events_on_app_env"
    t.index ["feature_key", "occurred_at"], name: "index_code_sunset_events_on_feature_key_and_occurred_at"
    t.index ["feature_key"], name: "index_code_sunset_events_on_feature_key"
    t.index ["hashed_org_id"], name: "index_code_sunset_events_on_hashed_org_id"
    t.index ["hashed_user_id"], name: "index_code_sunset_events_on_hashed_user_id"
    t.index ["metadata"], name: "index_code_sunset_events_on_metadata", using: :gin
    t.index ["occurred_at"], name: "index_code_sunset_events_on_occurred_at"
    t.index ["org_id"], name: "index_code_sunset_events_on_org_id"
    t.index ["plan"], name: "index_code_sunset_events_on_plan"
    t.index ["user_id"], name: "index_code_sunset_events_on_user_id"
  end

  create_table "code_sunset_features", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.string "owner"
    t.integer "remove_after_days_unused", default: 60, null: false
    t.string "status"
    t.integer "sunset_after_days", default: 90, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_code_sunset_features_on_key", unique: true
    t.index ["status"], name: "index_code_sunset_features_on_status"
  end
end
