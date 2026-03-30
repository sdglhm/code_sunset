require "test_helper"

class CodeSunsetEventTest < ActiveSupport::TestCase
  test "hashes configured identity fields before persistence" do
    CodeSunset.configure do |config|
      config.hash_identity = true
      config.identity_fields = %i[user_id org_id]
    end

    event = CodeSunset::Event.create_from_payload(
      feature_key: "legacy.feature",
      occurred_at: Time.current,
      user_id: 22,
      org_id: 91,
      metadata: {}
    )

    assert_nil event.user_id
    assert_nil event.org_id
    assert_equal CodeSunset::IdentityHash.digest(22), event.hashed_user_id
    assert_equal CodeSunset::IdentityHash.digest(91), event.hashed_org_id
  end

  test "creates a feature record when tracking an unregistered feature" do
    assert_difference("CodeSunset::Feature.count", 1) do
      CodeSunset::Event.create_from_payload(
        feature_key: "legacy.unregistered",
        occurred_at: Time.current,
        metadata: {}
      )
    end

    assert_equal "legacy.unregistered", CodeSunset::Feature.last.key
  end

  test "applies configured metadata filters" do
    CodeSunset.configure do |config|
      config.custom_filters = {
        region: { label: "Region", type: :string, metadata_key: "region" },
        beta_opt_in: { label: "Beta Opt-In", type: :boolean, metadata_key: "beta_opt_in" }
      }
    end

    matching = CodeSunset::Event.create!(
      feature_key: "legacy.metadata.match",
      occurred_at: Time.current,
      metadata: { region: "eu", beta_opt_in: true }
    )

    CodeSunset::Event.create!(
      feature_key: "legacy.metadata.other",
      occurred_at: Time.current,
      metadata: { region: "us", beta_opt_in: false }
    )

    filtered = CodeSunset::Event.apply_filters(region: "eu", beta_opt_in: true)

    assert_equal [matching.id], filtered.pluck(:id)
  end
end
