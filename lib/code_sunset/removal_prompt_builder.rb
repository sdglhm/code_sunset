require "find"
require "pathname"

module CodeSunset
  RemovalPromptArtifact = Struct.new(
    :prompt_markdown,
    :evidence_markdown,
    :summary,
    :search_matches,
    :signals,
    :warnings,
    keyword_init: true
  )

  class RemovalPromptBuilder
    SearchMatch = Struct.new(:path, :line_number, :line_preview, keyword_init: true)

    SEARCH_DIRECTORIES = %w[app config lib db test spec].freeze
    EXCLUDED_DIRECTORY_NAMES = %w[log tmp storage node_modules .git].freeze
    EXCLUDED_PATH_FRAGMENTS = ["vendor/bundle"].freeze
    MATCH_LIMIT = 20
    RECENT_EVENT_LIMIT = 5
    PREVIEW_LIMIT = 180

    def initialize(feature:, snapshot:, filters:, top_orgs:, top_users:, request_paths:, job_usage:, recent_events:, recent_events_total_count:, usage_series:, root: Rails.root)
      @feature = feature
      @snapshot = snapshot
      @filters = filters.to_h.symbolize_keys
      @top_orgs = Array(top_orgs)
      @top_users = Array(top_users)
      @request_paths = Array(request_paths)
      @job_usage = Array(job_usage)
      @recent_events = Array(recent_events)
      @recent_events_total_count = recent_events_total_count.to_i
      @usage_series = usage_series.to_h
      @root = Pathname.new(root.to_s)
    end

    def call
      search_matches = build_search_matches
      warnings = build_warnings(search_matches)
      signals = build_signals(search_matches)

      RemovalPromptArtifact.new(
        prompt_markdown: build_prompt(signals, warnings, search_matches),
        evidence_markdown: build_evidence(signals, warnings, search_matches),
        summary: build_summary,
        search_matches: search_matches,
        signals: signals,
        warnings: warnings
      )
    end

    private

    attr_reader :feature, :snapshot, :filters, :top_orgs, :top_users, :request_paths, :job_usage, :recent_events, :recent_events_total_count, :usage_series, :root

    def build_prompt(signals, warnings, search_matches)
      lines = []
      lines << "# Removal Prompt: #{feature.key}"
      lines << ""
      lines << "You are helping remove the Rails feature `#{feature.key}` conservatively."
      lines << ""
      lines << "## Objective"
      lines << "Assess whether `#{feature.key}` can be retired and identify the safest way to remove the feature and associated code."
      lines << ""
      lines << "## Working Rules"
      lines << "- Treat runtime evidence as the source of truth for recent usage."
      lines << "- Inspect the code references below before changing anything."
      lines << "- Prefer staged disablement or guarded rollout steps before hard deletion when risk is non-trivial."
      lines << "- If the evidence is insufficient for deletion, say so clearly and recommend the next safest step."
      lines << ""
      lines << "## Runtime Evidence"
      lines << "- Status: #{signals[:status]}"
      lines << "- Removal score: #{signals[:score]}"
      lines << "- Last seen: #{signals[:last_seen]}"
      lines << "- Activity: #{signals[:hits_7d]} hits in 7d, #{signals[:hits_30d]} hits in 30d"
      lines << "- Reach: #{signals[:unique_orgs_count]} orgs, #{signals[:unique_users_count]} users in 30d"
      lines << "- Paid usage: #{signals[:paid_hits_30d]}"
      lines << "- Filters applied: #{signals[:filter_context]}"
      lines << "- Repo matches found: #{search_matches.count}"
      lines << ""
      lines << "## What To Do"
      lines << "1. Verify whether this feature still appears necessary based on the runtime evidence."
      lines << "2. Review the matching code references and identify controllers, jobs, services, views, routes, tests, configs, and docs tied to `#{feature.key}`."
      lines << "3. Propose the safest removal approach, including any staged disablement, cleanup ordering, and rollback considerations."
      lines << "4. List the exact files likely to change."
      lines << "5. Call out risks, unknowns, and what would block safe removal."
      lines << "6. Provide a verification plan covering tests, runtime checks, and post-removal monitoring."
      lines << ""
      lines << "## Expected Output"
      lines << "- A short assessment of whether the feature is removable now"
      lines << "- A conservative removal plan"
      lines << "- The exact files to inspect or change"
      lines << "- Risks and unknowns"
      lines << "- Verification steps"
      lines << ""
      lines << "## Notes"
      lines << "- Recent event detail and raw-only filters may be limited by retained raw event history."
      lines << "- Use the evidence pack below as the starting point, then inspect the codebase directly as needed."
      if warnings.any?
        lines << ""
        lines << "## Warnings"
        warnings.each { |warning| lines << "- #{warning}" }
      end
      lines.join("\n")
    end

    def build_evidence(signals, warnings, search_matches)
      lines = []
      lines << "# Evidence Pack: #{feature.key}"
      lines << ""
      lines << "## Summary"
      lines << summary_line(build_summary)
      lines << ""
      lines << "## Feature Metadata"
      lines << summary_line("Owner: #{feature.owner.presence || "Unassigned"}")
      lines << summary_line("Description: #{feature.description.presence || "No description provided."}")
      lines << summary_line("Sunset after days: #{feature.sunset_after_days}")
      lines << summary_line("Remove after days unused: #{feature.remove_after_days_unused}")
      lines << ""
      lines << "## Runtime Signals"
      lines << summary_line("Status: #{signals[:status]}")
      lines << summary_line("Removal score: #{signals[:score]}")
      lines << summary_line("Last seen: #{signals[:last_seen]}")
      lines << summary_line("Hits: #{signals[:hits_7d]} in 7d, #{signals[:hits_30d]} in 30d")
      lines << summary_line("Reach: #{signals[:unique_orgs_count]} orgs, #{signals[:unique_users_count]} users in 30d")
      lines << summary_line("Paid usage in 30d: #{signals[:paid_hits_30d]}")
      lines << summary_line("Filters applied: #{signals[:filter_context]}")
      lines << summary_line("Trend points captured: #{signals[:usage_points]}")
      lines << ""
      lines << "## Score Breakdown"
      score_breakdown.each do |label, detail|
        lines << summary_line("#{label}: #{detail}")
      end
      lines << ""
      lines << "## Top Orgs"
      lines.concat(list_or_empty(top_orgs))
      lines << ""
      lines << "## Top Users"
      lines.concat(list_or_empty(top_users))
      lines << ""
      lines << "## Request Paths"
      lines.concat(list_or_empty(request_paths))
      lines << ""
      lines << "## Job Classes"
      lines.concat(list_or_empty(job_usage))
      lines << ""
      lines << "## Recent Event Window"
      lines << summary_line(recent_event_window_note)
      lines.concat(recent_event_lines)
      lines << ""
      lines << "## Exact Host-App Matches"
      if search_matches.any?
        search_matches.each do |match|
          lines << summary_line("`#{match.path}:#{match.line_number}` — #{match.line_preview}")
        end
      else
        lines << summary_line("No exact feature-key references were found under #{SEARCH_DIRECTORIES.join(', ')}.")
      end
      if warnings.any?
        lines << ""
        lines << "## Warnings"
        warnings.each { |warning| lines << summary_line(warning) }
      end
      lines.join("\n")
    end

    def build_summary
      case snapshot&.status
      when "safe_to_remove"
        "This feature looks like a low-risk removal candidate based on inactivity and the current removal score."
      when "candidate_for_removal"
        "This feature appears close to removable, but the remaining references and recent signals should be reviewed before code is deleted."
      when "cooling_down"
        "This feature is trending toward removal, but recent usage still suggests a staged approach."
      else
        "This feature still shows active or uncertain usage and should be treated as a higher-risk removal candidate."
      end
    end

    def build_signals(search_matches)
      {
        status: snapshot&.status.to_s.tr("_", " ").titleize.presence || "Unknown",
        score: format("%.1f/100", snapshot&.score.to_f),
        last_seen: if snapshot&.last_seen_at.present?
          snapshot.last_seen_at.in_time_zone.strftime("%Y-%m-%d %H:%M:%S %Z")
        else
          "Never observed"
        end,
        hits_7d: snapshot&.hits_7d.to_i,
        hits_30d: snapshot&.hits_30d.to_i,
        unique_orgs_count: snapshot&.unique_orgs_count.to_i,
        unique_users_count: snapshot&.unique_users_count.to_i,
        paid_hits_30d: snapshot&.paid_hits_30d.to_i,
        usage_points: usage_series.size,
        filter_context: filter_context,
        search_match_count: search_matches.count
      }
    end

    def build_warnings(search_matches)
      warnings = []
      warnings << analytics.raw_filter_notice if analytics.raw_filter_notice.present?
      warnings << "Paid-org traffic still exists in the last 30 days." if snapshot&.paid_hits_30d.to_i.positive?
      warnings << "The feature still has hits in the last 7 days." if snapshot&.hits_7d.to_i.positive?
      warnings << "No recent runtime events matched the selected filters." if recent_events_total_count.zero?
      warnings << "No exact feature-key references were found in the host app." if search_matches.empty?
      warnings
    end

    def score_breakdown
      return {} unless snapshot

      calculator = CodeSunset::ScoreCalculator.new(feature: feature, snapshot: snapshot)
      calculator.breakdown.transform_values do |component|
        "#{format('%.1f', component[:score])}/#{format('%.0f', component[:max])} from #{component[:detail]}"
      end.transform_keys do |key|
        key.to_s.tr("_", " ").titleize
      end
    end

    def list_or_empty(entries)
      return [summary_line("None in the current window.")] if entries.empty?

      entries.map do |identifier, hits|
        summary_line("`#{identifier}` — #{hits.to_i} hits")
      end
    end

    def recent_event_window_note
      "Showing #{[recent_events.size, RECENT_EVENT_LIMIT].min} of #{recent_events_total_count} recent events that matched the current filters."
    end

    def recent_event_lines
      return [summary_line("No recent events matched the selected filters.")] if recent_events.empty?

      recent_events.first(RECENT_EVENT_LIMIT).map do |event|
        summary_line("#{event.occurred_at.in_time_zone.strftime('%Y-%m-%d %H:%M:%S %Z')} — #{event.request_path.presence || event.job_class.presence || event.source}")
      end
    end

    def build_search_matches
      matches = []

      searchable_files.each do |path|
        File.foreach(path, encoding: "UTF-8", invalid: :replace, undef: :replace, replace: "").with_index(1) do |line, line_number|
          next unless line.include?(feature.key)

          matches << SearchMatch.new(
            path: relative_path(path),
            line_number: line_number,
            line_preview: compact_preview(line)
          )
          return matches if matches.size >= MATCH_LIMIT
        end
      rescue StandardError
        next
      end

      matches
    end

    def searchable_files
      files = []

      SEARCH_DIRECTORIES.each do |entry|
        directory = root.join(entry)
        next unless directory.exist?

        Find.find(directory.to_s) do |path|
          if File.directory?(path)
            basename = File.basename(path)
            if EXCLUDED_DIRECTORY_NAMES.include?(basename) || excluded_path_fragment?(path)
              Find.prune
            else
              next
            end
          end

          next unless File.file?(path)
          next if excluded_path_fragment?(path)
          next unless text_file?(path)

          files << path
        end
      end

      files.sort
    end

    def excluded_path_fragment?(path)
      EXCLUDED_PATH_FRAGMENTS.any? { |fragment| path.include?(fragment) }
    end

    def text_file?(path)
      sample = File.binread(path, 1024)
      !sample.include?("\x00")
    rescue StandardError
      false
    end

    def compact_preview(line)
      compact = line.to_s.strip.gsub(/\s+/, " ")
      return compact if compact.length <= PREVIEW_LIMIT

      "#{compact[0, PREVIEW_LIMIT - 1]}…"
    end

    def relative_path(path)
      Pathname.new(path).relative_path_from(root).to_s
    end

    def filter_context
      visible_filters = filters.except(:page)
      return "None" if visible_filters.blank?

      visible_filters.map do |key, value|
        "#{key}=#{value}"
      end.join(", ")
    end

    def analytics
      @analytics ||= CodeSunset::AnalyticsFilters.new(filters)
    end

    def summary_line(text)
      "- #{text}"
    end
  end
end
