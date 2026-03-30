require "test_helper"

class CodeSunsetAlertDispatcherTest < ActiveSupport::TestCase
  test "posts to the configured webhook once per cooldown window" do
    feature = CodeSunset::Feature.create!(
      key: "legacy.alert",
      sunset_after_days: 0,
      remove_after_days_unused: 0,
      created_at: 40.days.ago
    )

    CodeSunset::Event.create!(
      feature_key: feature.key,
      occurred_at: 15.days.ago,
      org_id: 1,
      metadata: {}
    )
    CodeSunset::Event.create!(
      feature_key: feature.key,
      occurred_at: 1.day.ago,
      org_id: 1,
      metadata: {}
    )

    delivered = nil
    CodeSunset.configure do |config|
      config.alert_webhook_proc = ->(payload) { delivered = payload }
      config.alert_cooldown = 24.hours
    end

    assert_difference("CodeSunset::AlertDelivery.count", 1) do
      CodeSunset::AlertDispatcher.new(feature.key).dispatch_if_due
    end

    assert_equal feature.key, delivered[:feature_key]
    assert_operator delivered[:hits_7d], :>, 0

    delivered = nil
    assert_no_difference("CodeSunset::AlertDelivery.count") do
      CodeSunset::AlertDispatcher.new(feature.key).dispatch_if_due
    end
    assert_nil delivered

    travel 25.hours do
      assert_difference("CodeSunset::AlertDelivery.count", 1) do
        CodeSunset::AlertDispatcher.new(feature.key).dispatch_if_due
      end
    end
  end
end
