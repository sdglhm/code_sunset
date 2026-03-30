require "test_helper"
require "fileutils"
require "tmpdir"

class CodeSunsetRemovalPromptBuilderTest < ActiveSupport::TestCase
  test "builds prompt and evidence with runtime signals and repo matches" do
    Dir.mktmpdir do |dir|
      write_file(dir, "app/services/legacy_billing.rb", <<~RUBY)
        class LegacyBilling
          FEATURE_KEY = "legacy.billing.portal"
        end
      RUBY
      write_file(dir, "tmp/ignored.txt", 'legacy.billing.portal')

      feature = CodeSunset::Feature.new(
        key: "legacy.billing.portal",
        owner: "billing",
        description: "Legacy billing flow",
        sunset_after_days: 90,
        remove_after_days_unused: 60,
        created_at: Time.zone.parse("2026-01-01 00:00:00 UTC")
      )
      snapshot = CodeSunset::FeatureSnapshot.new(
        feature: feature,
        last_seen_at: 40.days.ago,
        hits_7d: 1,
        hits_30d: 5,
        unique_orgs_count: 2,
        unique_users_count: 3,
        paid_hits_30d: 0,
        status: "candidate_for_removal",
        score: 0.0
      )
      snapshot.score = CodeSunset::ScoreCalculator.new(feature: feature, snapshot: snapshot).score

      artifact = CodeSunset::RemovalPromptBuilder.new(
        feature: feature,
        snapshot: snapshot,
        filters: { app_env: "production" },
        top_orgs: [["org-1", 3]],
        top_users: [["user-9", 2]],
        request_paths: [["/legacy/billing", 5]],
        job_usage: [["LegacyBillingJob", 1]],
        recent_events: [],
        recent_events_total_count: 0,
        usage_series: { Date.new(2026, 3, 28) => 2, Date.new(2026, 3, 29) => 1 },
        root: dir
      ).call

      assert_includes artifact.prompt_markdown, "# Removal Prompt: legacy.billing.portal"
      assert_includes artifact.prompt_markdown, "## Runtime Evidence"
      assert_includes artifact.prompt_markdown, "## What To Do"
      assert_includes artifact.evidence_markdown, "# Evidence Pack: legacy.billing.portal"
      assert_includes artifact.evidence_markdown, "## Exact Host-App Matches"
      assert_equal 1, artifact.search_matches.count
      assert_equal "app/services/legacy_billing.rb", artifact.search_matches.first.path
      assert_equal 2, artifact.search_matches.first.line_number
      assert_includes artifact.search_matches.first.line_preview, 'FEATURE_KEY = "legacy.billing.portal"'
      refute_includes artifact.evidence_markdown, "tmp/ignored.txt"
    end
  end

  test "warns when there are no matches or recent events" do
    Dir.mktmpdir do |dir|
      feature = CodeSunset::Feature.new(
        key: "legacy.empty.feature",
        created_at: Time.zone.parse("2026-01-01 00:00:00 UTC")
      )
      snapshot = CodeSunset::FeatureSnapshot.new(
        feature: feature,
        last_seen_at: nil,
        hits_7d: 0,
        hits_30d: 0,
        unique_orgs_count: 0,
        unique_users_count: 0,
        paid_hits_30d: 0,
        status: "safe_to_remove",
        score: 88.0
      )

      artifact = CodeSunset::RemovalPromptBuilder.new(
        feature: feature,
        snapshot: snapshot,
        filters: {},
        top_orgs: [],
        top_users: [],
        request_paths: [],
        job_usage: [],
        recent_events: [],
        recent_events_total_count: 0,
        usage_series: {},
        root: dir
      ).call

      assert_includes artifact.summary, "low-risk removal candidate"
      assert_includes artifact.warnings, "No recent runtime events matched the selected filters."
      assert_includes artifact.warnings, "No exact feature-key references were found in the host app."
      assert_includes artifact.evidence_markdown, "Never observed"
      assert_includes artifact.evidence_markdown, "No recent events matched the selected filters."
    end
  end

  test "uses more cautious wording for active features" do
    Dir.mktmpdir do |dir|
      feature = CodeSunset::Feature.new(
        key: "legacy.active.feature",
        created_at: Time.zone.parse("2026-01-01 00:00:00 UTC")
      )
      snapshot = CodeSunset::FeatureSnapshot.new(
        feature: feature,
        last_seen_at: 1.day.ago,
        hits_7d: 12,
        hits_30d: 30,
        unique_orgs_count: 6,
        unique_users_count: 10,
        paid_hits_30d: 4,
        status: "active",
        score: 11.0
      )

      artifact = CodeSunset::RemovalPromptBuilder.new(
        feature: feature,
        snapshot: snapshot,
        filters: { plan: "pro" },
        top_orgs: [],
        top_users: [],
        request_paths: [],
        job_usage: [],
        recent_events: [],
        recent_events_total_count: 0,
        usage_series: {},
        root: dir
      ).call

      assert_includes artifact.summary, "higher-risk removal candidate"
      assert_includes artifact.warnings, "Paid-org traffic still exists in the last 30 days."
      assert_includes artifact.warnings, "The feature still has hits in the last 7 days."
      assert_includes artifact.warnings.join(" "), "retained raw events only"
    end
  end

  test "caps repo matches to a deterministic limit" do
    Dir.mktmpdir do |dir|
      25.times do |index|
        write_file(dir, "app/services/match_#{index}.rb", %Q(class Match#{index}; FEATURE = "legacy.match.limit"; end\n))
      end

      feature = CodeSunset::Feature.new(
        key: "legacy.match.limit",
        created_at: Time.zone.parse("2026-01-01 00:00:00 UTC")
      )
      snapshot = CodeSunset::FeatureSnapshot.new(
        feature: feature,
        last_seen_at: 15.days.ago,
        hits_7d: 0,
        hits_30d: 0,
        unique_orgs_count: 0,
        unique_users_count: 0,
        paid_hits_30d: 0,
        status: "candidate_for_removal",
        score: 70.0
      )

      artifact = CodeSunset::RemovalPromptBuilder.new(
        feature: feature,
        snapshot: snapshot,
        filters: {},
        top_orgs: [],
        top_users: [],
        request_paths: [],
        job_usage: [],
        recent_events: [],
        recent_events_total_count: 0,
        usage_series: {},
        root: dir
      ).call

      assert_equal 20, artifact.search_matches.count
      assert_equal "app/services/match_0.rb", artifact.search_matches.first.path
      assert_equal "app/services/match_4.rb", artifact.search_matches.last.path
    end
  end

  private

  def write_file(root, relative_path, content)
    path = File.join(root, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end
end
