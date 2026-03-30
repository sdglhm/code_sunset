require "test_helper"
require "fileutils"

class CodeSunsetDashboardTest < ActionDispatch::IntegrationTest
  test "renders the mounted dashboard" do
    CodeSunset::Event.create_from_payload(
      feature_key: "legacy.dashboard",
      occurred_at: Time.current,
      metadata: {}
    )

    get "/code_sunset"

    assert_response :success
    assert_includes @response.body, "Tracked Features"
    assert_includes @response.body, "legacy.dashboard"
  end

  test "supports feature detail routes with dotted keys" do
    CodeSunset::Feature.create!(key: "legacy.billing.portal")

    get "/code_sunset/features/legacy.billing.portal"

    assert_response :success
    assert_includes @response.body, "legacy.billing.portal"
  end

  test "shows a raw-event notice when raw-only filters are active" do
    get "/code_sunset/features", params: { plan: "pro" }

    assert_response :success
    assert_includes @response.body, "retained raw events only"
  end

  test "shows primary filters, advanced filters, and active filter chips" do
    get "/code_sunset/features", params: { app_env: "production", plan: "pro", exclude_internal: true }

    assert_response :success
    assert_includes @response.body, "More Filters"
    assert_includes @response.body, "Environment:"
    assert_includes @response.body, "production"
    assert_includes @response.body, "Plan:"
    assert_includes @response.body, "pro"
    assert_includes @response.body, "Internal:"
    assert_includes @response.body, "Excluded"
    assert_includes @response.body, "User ID"
  end

  test "renders configured custom metadata filters and chips" do
    configure_custom_filters

    get "/code_sunset/features", params: { region: "eu", beta_opt_in: true, account_tier: "pro" }

    assert_response :success
    assert_includes @response.body, "Region"
    assert_includes @response.body, "Beta Opt-In"
    assert_includes @response.body, "Account Tier"
    assert_includes @response.body, "Environment and dates use rollups where possible"
    assert_includes @response.body, "Region:"
    assert_includes @response.body, "eu"
    assert_includes @response.body, "Beta Opt-In:"
    assert_includes @response.body, "Yes"
    assert_includes @response.body, "Account Tier:"
    assert_includes @response.body, "Pro"
  end

  test "dashboard stays unfiltered and links to clean destinations" do
    configure_custom_filters
    CodeSunset::Event.create_from_payload(
      feature_key: "legacy.filtered.dashboard",
      occurred_at: Time.current,
      metadata: { "region" => "eu" }
    )

    get "/code_sunset", params: { region: "eu" }

    assert_response :success
    assert_not_includes @response.body, "Filter Overview"
    assert_not_includes @response.body, "Filter Feature Usage"
    assert_not_includes @response.body, "Filter Removal Queue"
    assert_includes @response.body, "/code_sunset/features/legacy.filtered.dashboard"
    assert_includes @response.body, "/code_sunset/features"
    assert_includes @response.body, "/code_sunset/removal_candidates"
  end

  test "feature detail renders the shared custom filter bar" do
    configure_custom_filters
    feature = CodeSunset::Feature.create!(key: "legacy.filtered.detail")
    CodeSunset::Event.create!(
      feature_key: feature.key,
      occurred_at: Time.current,
      metadata: { "region" => "eu" },
      app_env: "test"
    )

    get "/code_sunset/features/#{feature.key}", params: { region: "eu" }

    assert_response :success
    assert_includes @response.body, "Filter Feature Usage"
    assert_includes @response.body, "Region"
    assert_includes @response.body, "Region:"
    assert_includes @response.body, "eu"
    assert_includes @response.body, "retained raw events only"
    assert_includes @response.body, "/code_sunset/features/#{feature.key}"
  end

  test "feature detail does not render a removal prompt by default" do
    feature = CodeSunset::Feature.create!(key: "legacy.prompt.default")

    get "/code_sunset/features/#{feature.key}"

    assert_response :success
    assert_includes @response.body, "Generate Removal Prompt"
    assert_not_includes @response.body, "Evidence Pack"
    assert_not_includes @response.body, "Copy Prompt"
  end

  test "feature detail renders a removal prompt on explicit request and preserves filters" do
    configure_custom_filters
    feature = CodeSunset::Feature.create!(key: "legacy.prompt.feature", owner: "billing")
    CodeSunset::Event.create!(
      feature_key: feature.key,
      occurred_at: Time.current,
      metadata: { "region" => "eu" },
      app_env: "test"
    )

    created_path = Rails.root.join("app/services/legacy_prompt_feature.rb")
    FileUtils.mkdir_p(created_path.dirname)
    File.write(created_path, %(class LegacyPromptFeature\n  FEATURE_KEY = "#{feature.key}"\nend\n))

    get "/code_sunset/features/#{feature.key}", params: { region: "eu", generate_removal_prompt: true }

    assert_response :success
    assert_includes @response.body, "Regenerate Removal Prompt"
    assert_includes @response.body, "Copy Prompt"
    assert_includes @response.body, "data-copy-target=\"cs-removal-prompt\""
    assert_includes @response.body, "# Removal Prompt: #{feature.key}"
    assert_includes @response.body, "# Evidence Pack: #{feature.key}"
    assert_includes @response.body, "Filters applied: region=eu"
    assert_includes @response.body, "app/services/legacy_prompt_feature.rb:2"
    assert_includes @response.body, "generate_removal_prompt=true"
    assert_includes @response.body, "region=eu"
  ensure
    File.delete(created_path) if created_path && File.exist?(created_path)
  end

  test "removal queue renders the shared custom filter bar" do
    configure_custom_filters

    get "/code_sunset/removal_candidates", params: { region: "eu" }

    assert_response :success
    assert_includes @response.body, "Filter Removal Queue"
    assert_includes @response.body, "Region"
    assert_includes @response.body, "Region:"
    assert_includes @response.body, "eu"
    assert_includes @response.body, "retained raw events only"
  end

  test "paginates recent events on the feature detail page" do
    feature = CodeSunset::Feature.create!(key: "legacy.paginated.events")

    30.times do |index|
      CodeSunset::Event.create!(
        feature_key: feature.key,
        occurred_at: Time.current - index.minutes,
        app_env: "test"
      )
    end

    get "/code_sunset/features/#{feature.key}", params: { page: 2 }

    assert_response :success
    assert_includes @response.body, "Page 2 of 2"
    assert_includes @response.body, "26-30 of 30"
    assert_includes @response.body, "Previous"
  end

  private

  def configure_custom_filters
    CodeSunset.configure do |config|
      config.dashboard_authorizer = ->(_controller) { true }
      config.custom_filters = {
        region: { label: "Region", type: :string, metadata_key: "region" },
        beta_opt_in: { label: "Beta Opt-In", type: :boolean, metadata_key: "beta_opt_in" },
        account_tier: { label: "Account Tier", type: :select, metadata_key: "tier", options: [["Free", "free"], ["Pro", "pro"]] }
      }
    end
  end
end
