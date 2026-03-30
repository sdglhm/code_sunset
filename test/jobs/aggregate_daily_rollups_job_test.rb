require "test_helper"

class CodeSunsetAggregateDailyRollupsJobTest < ActiveSupport::TestCase
  test "aggregates raw events into daily rollups" do
    feature = CodeSunset::Feature.create!(key: "legacy.rollup")

    3.times do |index|
      CodeSunset::Event.create!(
        feature_key: feature.key,
        occurred_at: Time.zone.parse("2026-03-20 10:0#{index}:00"),
        user_id: index + 1,
        org_id: 100,
        metadata: {}
      )
    end

    CodeSunset::AggregateDailyRollupsJob.perform_now(start_date: "2026-03-20", end_date: "2026-03-20")

    rollup = CodeSunset::DailyRollup.find_by!(feature_key: feature.key, day: Date.parse("2026-03-20"))
    assert_equal 3, rollup.hits_count
    assert_equal 3, rollup.unique_users_count
    assert_equal 1, rollup.unique_orgs_count
  end
end
