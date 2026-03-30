module CodeSunset
  class ScoreCalculator
    def initialize(feature:, snapshot:)
      @feature = feature
      @snapshot = snapshot
    end

    def score
      return 0.0 unless snapshot

      breakdown.values.sum { |component| component[:score] }.round(2)
    end

    def breakdown
      return {} unless snapshot

      {
        recency: recency_breakdown,
        volume: volume_breakdown,
        orgs: org_breakdown,
        paid_usage: paid_usage_breakdown
      }
    end

    private

    attr_reader :feature, :snapshot

    def days_unused
      @days_unused ||= if snapshot.last_seen_at.present?
        (Time.current.to_date - snapshot.last_seen_at.to_date).to_i
      else
        (Time.current.to_date - (feature.created_at || Time.current).to_date).to_i
      end
    end

    def recency_breakdown
      score = ([days_unused, 120].min / 120.0 * 45).round(2)

      {
        score: score,
        max: 45.0,
        detail: "#{days_unused} days unused"
      }
    end

    def volume_breakdown
      recent_hits = [snapshot.hits_30d.to_i, 100].min
      score = ((1 - (recent_hits / 100.0)) * 25).round(2)

      {
        score: score,
        max: 25.0,
        detail: "#{snapshot.hits_30d.to_i} hits in last 30d"
      }
    end

    def org_breakdown
      orgs = [snapshot.unique_orgs_count.to_i, 20].min
      score = ((1 - (orgs / 20.0)) * 20).round(2)

      {
        score: score,
        max: 20.0,
        detail: "#{snapshot.unique_orgs_count.to_i} orgs in last 30d"
      }
    end

    def paid_usage_breakdown
      score = snapshot.paid_hits_30d.to_i.zero? ? 10.0 : 0.0

      {
        score: score,
        max: 10.0,
        detail: if snapshot.paid_hits_30d.to_i.zero?
          "no paid hits in last 30d"
        else
          "#{snapshot.paid_hits_30d.to_i} paid hits in last 30d"
        end
      }
    end
  end
end
