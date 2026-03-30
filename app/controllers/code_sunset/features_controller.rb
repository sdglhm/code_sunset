module CodeSunset
  class FeaturesController < ApplicationController
    RECENT_EVENTS_PER_PAGE = 25

    before_action :load_feature, only: :show

    def index
      @summaries = CodeSunset::FeatureQuery.new(filters).call
    end

    def show
      @summary = CodeSunset::FeatureQuery.new(filters, scope: CodeSunset::Feature.where(id: @feature.id)).call.first
      @usage_series = CodeSunset::FeatureUsageSeries.new(feature: @feature, filters: filters).call

      scoped_events = @feature.events.apply_filters(filters).where(occurred_at: 30.days.ago..Time.current)
      @top_orgs = CodeSunset::Event.top_orgs(scoped_events, limit: 8)
      @top_users = CodeSunset::Event.top_users(scoped_events, limit: 8)
      @request_paths = CodeSunset::Event.top_request_paths(scoped_events, limit: 8)
      @job_usage = CodeSunset::Event.top_job_classes(scoped_events, limit: 8)

      recent_events_scope = @feature.events.apply_filters(filters.except(:page)).recent_first
      @recent_events_page = requested_recent_events_page
      @recent_events_per_page = RECENT_EVENTS_PER_PAGE
      @recent_events_total_count = recent_events_scope.count
      @recent_events_total_pages = [(@recent_events_total_count.to_f / @recent_events_per_page).ceil, 1].max
      @recent_events_page = [@recent_events_page, @recent_events_total_pages].min
      @recent_events = recent_events_scope.offset((@recent_events_page - 1) * @recent_events_per_page).limit(@recent_events_per_page)

      @removal_prompt_artifact = build_removal_prompt_artifact if generate_removal_prompt?
    end

    private

    def load_feature
      @feature = CodeSunset::Feature.find_by!(key: params[:id])
    end

    def requested_recent_events_page
      page = params[:page].to_i
      page.positive? ? page : 1
    end

    def generate_removal_prompt?
      ActiveModel::Type::Boolean.new.cast(params[:generate_removal_prompt])
    end

    def build_removal_prompt_artifact
      CodeSunset::RemovalPromptBuilder.new(
        feature: @feature,
        snapshot: @summary,
        filters: filters,
        top_orgs: @top_orgs,
        top_users: @top_users,
        request_paths: @request_paths,
        job_usage: @job_usage,
        recent_events: @recent_events,
        recent_events_total_count: @recent_events_total_count,
        usage_series: @usage_series
      ).call
    end
  end
end
