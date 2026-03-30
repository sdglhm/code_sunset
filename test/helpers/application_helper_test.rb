require "test_helper"
require "ostruct"

module CodeSunset
  class ApplicationHelperTest < ActionView::TestCase
    include ApplicationHelper

    test "format_seen_at returns never when timestamp is blank" do
      assert_equal "Never", format_seen_at(nil)
    end

    test "format_seen_at renders relative text with exact timestamp tooltip" do
      travel_to Time.zone.parse("2026-03-30 12:00:00 UTC") do
        rendered = format_seen_at(2.hours.ago)

        assert_includes rendered, ">about 2 hours ago<"
        assert_includes rendered, 'class="cs-time"'
        assert_includes rendered, 'datetime="2026-03-30T10:00:00Z"'
        assert_includes rendered, 'title="2026-03-30 10:00:00 UTC"'
      end
    end

    test "format_seen_at does not render future tense for future timestamps" do
      travel_to Time.zone.parse("2026-03-30 12:00:00 UTC") do
        rendered = format_seen_at(5.minutes.from_now)

        assert_includes rendered, ">just now<"
        refute_includes rendered, "in "
      end
    end

    test "usage_chart renders a chart canvas with serialized data" do
      rendered = usage_chart(
        Date.new(2026, 3, 28) => 3,
        Date.new(2026, 3, 29) => 7
      )

      assert_includes rendered, "data-code-sunset-usage-chart=\"true\""
      assert_includes rendered, "data-labels="
      assert_includes rendered, "data-values="
      assert_includes rendered, "Feature usage trend chart"
    end

    test "removal_score_badge includes a tooltip with scoring breakdown" do
      travel_to Time.zone.parse("2026-03-30 12:00:00 UTC") do
        feature = OpenStruct.new(created_at: Time.zone.parse("2026-01-01 00:00:00 UTC"))
        snapshot = CodeSunset::FeatureSnapshot.new(
          last_seen_at: 10.days.ago,
          hits_30d: 12,
          unique_orgs_count: 3,
          paid_hits_30d: 0,
          score: 0.0
        )
        snapshot.score = CodeSunset::ScoreCalculator.new(feature: feature, snapshot: snapshot).score

        rendered = removal_score_badge(feature, snapshot, label: "72.0")

        assert_includes rendered, ">72.0<"
        assert_includes rendered, 'class="cs-score cs-score--help"'
        assert_includes rendered, "Recency:"
        assert_includes rendered, "Volume:"
        assert_includes rendered, "Org breadth:"
        assert_includes rendered, "Paid usage:"
        assert_includes rendered, "Total:"
      end
    end

    test "filter_path_for preserves active filters and drops pagination" do
      CodeSunset.configure do |config|
        config.custom_filters = {
          region: { label: "Region", type: :string, metadata_key: "region" }
        }
      end

      define_singleton_method(:filters) do
        { app_env: "production", region: "eu", page: "2" }
      end

      assert_equal "/code_sunset/features/legacy.portal?app_env=production&region=eu", filter_path_for("/code_sunset/features/legacy.portal")
    end

    test "active_filter_chips_for builds removal links against the current page path" do
      CodeSunset.configure do |config|
        config.custom_filters = {
          region: { label: "Region", type: :string, metadata_key: "region" }
        }
      end

      define_singleton_method(:filters) do
        { app_env: "production", region: "eu", page: "3" }
      end

      chips = active_filter_chips_for("/code_sunset")

      assert_equal 2, chips.size
      assert_equal "Environment", chips.first[:label]
      assert_equal "/code_sunset?region=eu", chips.first[:clear_path]
      assert_equal "Region", chips.last[:label]
      assert_equal "/code_sunset?app_env=production", chips.last[:clear_path]
    end
  end
end
