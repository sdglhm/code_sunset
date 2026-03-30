module CodeSunset
  class FeatureUsageSeries
    DEFAULT_WINDOW_DAYS = 30

    def initialize(feature:, filters: {})
      @feature = feature
      @filters = filters.to_h.symbolize_keys
    end

    def call
      date_range = normalized_range
      analytics = CodeSunset::AnalyticsFilters.new(filters)

      series = if analytics.raw_dimension_filters?
        effective_range = analytics.retain_range(date_range)
        feature.events.apply_filters(analytics.raw_filters).where(occurred_at: effective_range).group("DATE(occurred_at)").count
      else
        rollup_series = feature.daily_rollups.apply_filters(analytics.rollup_filters).where(day: date_range.first.to_date..date_range.last.to_date).group(:day).sum(:hits_count)
        raw_series_fallback(rollup_series, date_range, analytics)
      end

      fill_gaps(series, date_range)
    end

    private

    attr_reader :feature, :filters

    def normalized_range
      from = parse_time(filters[:from]) || DEFAULT_WINDOW_DAYS.days.ago.beginning_of_day
      to = parse_time(filters[:to]) || Time.current.end_of_day
      from.beginning_of_day..to.end_of_day
    end

    def raw_series_fallback(rollup_series, date_range, analytics)
      return rollup_series if rollup_series.present?

      feature.events
        .apply_filters(analytics.rollup_filters)
        .where(occurred_at: date_range)
        .group("DATE(occurred_at)")
        .count
    end

    def parse_time(value)
      return if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def fill_gaps(series, date_range)
      (date_range.first.to_date..date_range.last.to_date).each_with_object({}) do |day, memo|
        memo[day] = series[day] || series[day.to_s] || 0
      end
    end
  end
end
