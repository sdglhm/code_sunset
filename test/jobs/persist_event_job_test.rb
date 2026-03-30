require "test_helper"

class CodeSunsetPersistEventJobTest < ActiveSupport::TestCase
  test "persisting an event does not enqueue alert evaluation per hit" do
    payload = {
      feature_key: "legacy.no_alert_fanout",
      occurred_at: Time.current,
      metadata: {}
    }

    assert_difference("CodeSunset::Event.count", 1) do
      assert_no_enqueued_jobs do
        CodeSunset::PersistEventJob.perform_now(payload)
      end
    end
  end
end
