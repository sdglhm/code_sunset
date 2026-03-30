require "test_helper"

class CodeSunsetContextTest < ActiveSupport::TestCase
  test "merges nested metadata within scoped context" do
    CodeSunset::Context.with(user_id: 12, metadata: { plan: "pro" }) do
      CodeSunset::Context.with(org_id: 44, metadata: { region: "us" }) do
        current = CodeSunset::Context.current

        assert_equal 12, current[:user_id]
        assert_equal 44, current[:org_id]
        assert_equal({ plan: "pro", region: "us" }, current[:metadata])
      end
    end
  end
end
