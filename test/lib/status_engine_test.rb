require "test_helper"

class CodeSunsetStatusEngineTest < ActiveSupport::TestCase
  setup do
    @feature = CodeSunset::Feature.create!(
      key: "legacy.status",
      sunset_after_days: 90,
      remove_after_days_unused: 60,
      created_at: 120.days.ago
    )
  end

  test "marks stale features as safe to remove" do
    status = CodeSunset::StatusEngine.new(
      feature: @feature,
      last_seen_at: 100.days.ago,
      reference_time: Time.current
    ).status

    assert_equal "safe_to_remove", status
  end

  test "marks moderately stale features as candidates for removal" do
    status = CodeSunset::StatusEngine.new(
      feature: @feature,
      last_seen_at: 70.days.ago,
      reference_time: Time.current
    ).status

    assert_equal "candidate_for_removal", status
  end
end
