module CodeSunset
  class FeatureQuery
    def initialize(filters = {}, scope: CodeSunset::Feature.ordered)
      @filters = filters.to_h.symbolize_keys
      @scope = scope
    end

    def call
      features = scope.to_a
      return [] if features.empty?

      metrics = metrics_by_feature_key(features.map(&:key))

      features.map do |feature|
        feature_metrics = metrics.fetch(feature.key, {})
        last_seen_at = feature_metrics[:last_seen_at]
        snapshot = CodeSunset::FeatureSnapshot.new(
          feature: feature,
          last_seen_at: last_seen_at,
          hits_7d: feature_metrics[:hits_7d].to_i,
          hits_30d: feature_metrics[:hits_30d].to_i,
          unique_orgs_count: feature_metrics[:unique_orgs_count].to_i,
          unique_users_count: feature_metrics[:unique_users_count].to_i,
          paid_hits_30d: feature_metrics[:paid_hits_30d].to_i,
          status: feature.computed_status(last_seen_at: last_seen_at),
          score: 0.0
        )

        snapshot.score = CodeSunset::ScoreCalculator.new(feature: feature, snapshot: snapshot).score
        snapshot
      end
    end

    private

    attr_reader :filters, :scope

    def metrics_by_feature_key(feature_keys)
      metrics = Hash.new { |hash, key| hash[key] = {} }
      analytics = CodeSunset::AnalyticsFilters.new(filters)

      if analytics.raw_dimension_filters?
        event_scope = CodeSunset::Event.where(feature_key: feature_keys).apply_filters(analytics.raw_filters)
        event_scope = event_scope.where(occurred_at: analytics.raw_retained_range)
        merge_metric!(metrics, CodeSunset::Event.grouped_last_seen(event_scope), :last_seen_at)
        recent_event_scope = event_scope
      else
        rollup_scope = CodeSunset::DailyRollup.where(feature_key: feature_keys).apply_filters(analytics.rollup_filters)
        merge_metric!(metrics, rollup_scope.group(:feature_key).maximum(:last_seen_at), :last_seen_at)
        current_event_scope = CodeSunset::Event.where(feature_key: feature_keys).apply_filters(analytics.rollup_filters)
        merge_metric!(metrics, CodeSunset::Event.grouped_last_seen(current_event_scope), :last_seen_at)
        recent_event_scope = CodeSunset::Event.where(feature_key: feature_keys).apply_filters(analytics.recent_raw_filters)
      end

      merge_metric!(metrics, CodeSunset::Event.grouped_counts(recent_event_scope.where(occurred_at: 7.days.ago..Time.current)), :hits_7d)
      merge_metric!(metrics, CodeSunset::Event.grouped_counts(recent_event_scope.where(occurred_at: 30.days.ago..Time.current)), :hits_30d)
      merge_metric!(metrics, CodeSunset::Event.grouped_counts(recent_event_scope.where(occurred_at: 30.days.ago..Time.current, paid_org: true)), :paid_hits_30d)
      merge_metric!(metrics, CodeSunset::Event.grouped_distinct_org_counts(recent_event_scope.where(occurred_at: 30.days.ago..Time.current)), :unique_orgs_count)
      merge_metric!(metrics, CodeSunset::Event.grouped_distinct_user_counts(recent_event_scope.where(occurred_at: 30.days.ago..Time.current)), :unique_users_count)
      metrics
    end

    def merge_metric!(metrics, values, key)
      values.each do |feature_key, value|
        metrics[feature_key][key] = value
      end
    end
  end
end
