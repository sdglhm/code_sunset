require "test_helper"

class CodeSunsetFeatureUsageSeriesTest < ActiveSupport::TestCase
  test "uses rollups for environment filtered history" do
    feature = CodeSunset::Feature.create!(key: "legacy.series")
    CodeSunset::DailyRollup.create!(
      feature_key: feature.key,
      app_env: "production",
      day: Date.new(2025, 2, 2),
      hits_count: 9,
      unique_users_count: 2,
      unique_orgs_count: 1,
      last_seen_at: Time.zone.parse("2025-02-02 09:00:00")
    )

    series = CodeSunset::FeatureUsageSeries.new(
      feature: feature,
      filters: { from: "2025-02-01", to: "2025-02-03", app_env: "production" }
    ).call

    assert_equal 9, series[Date.new(2025, 2, 2)]
  end

  test "falls back to raw events when rollups are missing" do
    travel_to Time.zone.parse("2026-03-30 12:00:00 UTC") do
      feature = CodeSunset::Feature.create!(key: "legacy.series.raw")
      CodeSunset::Event.create!(
        feature_key: feature.key,
        occurred_at: Time.zone.parse("2026-03-30 09:30:00 UTC"),
        app_env: "development"
      )

      series = CodeSunset::FeatureUsageSeries.new(
        feature: feature,
        filters: { from: "2026-03-29", to: "2026-03-30", app_env: "development" }
      ).call

      assert_equal 1, series[Date.new(2026, 3, 30)]
    end
  end
end
