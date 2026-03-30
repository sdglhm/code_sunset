module CodeSunset
  class StatusEngine
    def initialize(feature:, last_seen_at:, reference_time: Time.current)
      @feature = feature
      @last_seen_at = last_seen_at
      @reference_time = reference_time
    end

    def status
      return "safe_to_remove" if days_unused >= sunset_after_days
      return "candidate_for_removal" if days_unused >= remove_after_days_unused
      return "cooling_down" if days_unused >= cooling_down_days

      "active"
    end

    private

    attr_reader :feature, :last_seen_at, :reference_time

    def days_unused
      baseline = last_seen_at || feature.created_at || reference_time
      (reference_time.to_date - baseline.to_date).to_i
    end

    def sunset_after_days
      feature.sunset_after_days.presence || 90
    end

    def remove_after_days_unused
      feature.remove_after_days_unused.presence || 60
    end

    def cooling_down_days
      [14, (remove_after_days_unused / 2.0).ceil].max
    end
  end
end
