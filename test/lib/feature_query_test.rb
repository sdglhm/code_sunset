require "test_helper"

class CodeSunsetFeatureQueryTest < ActiveSupport::TestCase
  test "uses rollups for date range history after raw events are gone" do
    feature = CodeSunset::Feature.create!(key: "legacy.history")
    CodeSunset::DailyRollup.create!(
      feature_key: feature.key,
      app_env: "production",
      day: Date.new(2025, 1, 10),
      hits_count: 12,
      unique_users_count: 3,
      unique_orgs_count: 2,
      last_seen_at: Time.zone.parse("2025-01-10 18:00:00")
    )

    snapshot = CodeSunset::FeatureQuery.new(
      { from: "2025-01-01", to: "2025-01-31", app_env: "production" },
      scope: CodeSunset::Feature.where(id: feature.id)
    ).call.first

    assert_equal Time.zone.parse("2025-01-10 18:00:00"), snapshot.last_seen_at
  end

  test "falls back to raw event last seen when rollups are missing" do
    feature = CodeSunset::Feature.create!(key: "legacy.live_only")
    occurred_at = Time.zone.parse("2026-03-30 08:45:00")

    CodeSunset::Event.create!(
      feature_key: feature.key,
      occurred_at: occurred_at,
      app_env: "development",
      metadata: {}
    )

    snapshot = CodeSunset::FeatureQuery.new(
      { app_env: "development" },
      scope: CodeSunset::Feature.where(id: feature.id)
    ).call.first

    assert_equal occurred_at, snapshot.last_seen_at
  end

  test "raw dimension filters expose a retention notice" do
    notice = CodeSunset::AnalyticsFilters.new(plan: "pro").raw_filter_notice

    assert_includes notice, "retained raw events only"
    assert_includes notice, CodeSunset.configuration.event_retention_days.to_s
  end

  test "configured custom filters are treated as raw-dimension filters" do
    CodeSunset.configure do |config|
      config.custom_filters = {
        region: { label: "Region", type: :string, metadata_key: "region" }
      }
    end

    notice = CodeSunset::AnalyticsFilters.new(region: "eu").raw_filter_notice

    assert_includes notice, "Region"
    assert_includes notice, "retained raw events only"
  end
end
