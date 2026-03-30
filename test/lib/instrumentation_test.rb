require "test_helper"

class CodeSunsetInstrumentationTest < ActiveSupport::TestCase
  test "persists a hit through the notifications pipeline" do
    CodeSunset.configure do |config|
      config.async = false
      config.environment = "production"
    end

    assert_difference("CodeSunset::Event.count", 1) do
      CodeSunset.hit("legacy.billing.portal", user_id: 7, org_id: 10, metadata: { plan: "pro" })
    end

    event = CodeSunset::Event.last
    assert_equal "legacy.billing.portal", event.feature_key
    assert_equal 7, event.user_id
    assert_equal 10, event.org_id
    assert_equal "pro", event.metadata["plan"]
    assert_equal "production", event.app_env
  end

  test "registers features with defaults" do
    feature = CodeSunset.register("legacy.billing.portal", owner: "billing")

    assert_predicate feature, :persisted?
    assert_equal "billing", feature.owner
    assert_equal 90, feature.sunset_after_days
    assert_equal 60, feature.remove_after_days_unused
  end

  test "drops events when async enqueue fails and policy is drop" do
    CodeSunset.configure do |config|
      config.async = true
      config.enqueue_failure_policy = :drop
    end

    with_failing_enqueue do
      assert_no_difference("CodeSunset::Event.count") do
        CodeSunset.hit("legacy.async.drop")
      end
    end

    assert_equal 0, CodeSunset.event_buffer.size
  end

  test "buffers events when async enqueue fails and policy is memory_buffer" do
    CodeSunset.configure do |config|
      config.async = true
      config.enqueue_failure_policy = :memory_buffer
      config.enqueue_buffer_size = 1
    end

    with_failing_enqueue do
      assert_no_difference("CodeSunset::Event.count") do
        CodeSunset.hit("legacy.async.buffered")
      end

      assert_equal 1, CodeSunset.event_buffer.size

      assert_no_difference("CodeSunset::Event.count") do
        CodeSunset.hit("legacy.async.overflow")
      end
    end

    assert_equal 1, CodeSunset.event_buffer.size

    assert_difference("CodeSunset::Event.count", 1) do
      CodeSunset::FlushBufferedEventsJob.perform_now
    end

    assert_equal 0, CodeSunset.event_buffer.size
  end

  private

  def with_failing_enqueue
    job_singleton = CodeSunset::PersistEventJob.singleton_class
    original_method = job_singleton.instance_method(:perform_later)

    job_singleton.define_method(:perform_later) do |_payload|
      raise StandardError, "queue down"
    end

    yield
  ensure
    job_singleton.define_method(:perform_later, original_method)
  end
end
