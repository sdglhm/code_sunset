module CodeSunset
  class DashboardController < ApplicationController
    def index
      @summaries = CodeSunset::FeatureQuery.new(filters).call
      @active_count = @summaries.count { |summary| summary.status == "active" }
      @removable_count = @summaries.count { |summary| %w[candidate_for_removal safe_to_remove].include?(summary.status) }
      @recent_features = @summaries.select { |summary| summary.hits_7d.to_i.positive? }.sort_by { |summary| [-summary.hits_7d.to_i, summary.feature.key] }.first(6)
      @safe_to_remove = @summaries.select { |summary| summary.status == "safe_to_remove" }.sort_by { |summary| [-summary.score.to_f, summary.feature.key] }.first(4)
      @cooling_down = @summaries.select { |summary| summary.status == "candidate_for_removal" }.sort_by { |summary| [-summary.score.to_f, summary.feature.key] }.first(4)
    end
  end
end
