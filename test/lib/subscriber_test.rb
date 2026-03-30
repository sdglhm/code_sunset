require "test_helper"

class CodeSunsetSubscriberTest < ActiveSupport::TestCase
  test "subscribe is idempotent and can be reset" do
    CodeSunset::Subscriber.unsubscribe!

    first = CodeSunset::Subscriber.subscribe!
    second = CodeSunset::Subscriber.subscribe!

    assert_equal first, second
    assert_equal first, CodeSunset::Subscriber.subscription

    CodeSunset::Subscriber.unsubscribe!
    assert_nil CodeSunset::Subscriber.subscription
  ensure
    CodeSunset::Subscriber.subscribe!
  end
end
