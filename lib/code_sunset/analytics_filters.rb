module CodeSunset
  class AnalyticsFilters
    RAW_DIMENSION_KEYS = %i[org_id user_id plan paid_only exclude_internal].freeze

    def initialize(filters = {})
      @filters = filters.to_h.symbolize_keys
    end

    def raw_dimension_filters?
      raw_dimension_keys.any? { |key| filters[key].present? }
    end

    def raw_dimension_keys
      (RAW_DIMENSION_KEYS + CodeSunset.configuration.custom_filters.keys).select { |key| filters[key].present? }
    end

    def raw_filters
      filters.slice(:app_env, :plan, :org_id, :user_id, :paid_only, :exclude_internal, :from, :to, *CodeSunset.configuration.custom_filters.keys)
    end

    def recent_raw_filters
      filters.slice(:app_env)
    end

    def rollup_filters
      filters.slice(:app_env, :from, :to)
    end

    def retain_range(range)
      [range.begin, raw_retention_start].max..range.end
    end

    def raw_retained_range
      raw_retention_start..Time.current.end_of_day
    end

    def raw_filter_notice
      return unless raw_dimension_filters?

      keys = raw_dimension_keys.map { |key| filter_label_for(key) }.join(", ")
      "Filters for #{keys} use retained raw events only. Historical results are limited to the last #{CodeSunset.configuration.event_retention_days} days."
    end

    private

    attr_reader :filters

    def raw_retention_start
      CodeSunset.configuration.event_retention_days.days.ago.beginning_of_day
    end

    def filter_label_for(key)
      configured = CodeSunset.configuration.custom_filters[key.to_sym]
      return configured[:label] if configured

      key.to_s.tr("_", " ")
    end
  end
end
