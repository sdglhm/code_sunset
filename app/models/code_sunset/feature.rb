module CodeSunset
  class Feature < ApplicationRecord
    self.table_name = "code_sunset_features"

    STATUSES = %w[active cooling_down candidate_for_removal safe_to_remove].freeze

    has_many :events, primary_key: :key, foreign_key: :feature_key, inverse_of: :feature, dependent: :nullify
    has_many :daily_rollups, primary_key: :key, foreign_key: :feature_key, inverse_of: :feature, dependent: :delete_all

    validates :key, presence: true, uniqueness: true
    validates :status, inclusion: { in: STATUSES }, allow_blank: true

    before_validation :apply_defaults

    scope :ordered, -> { order(:key) }

    def computed_status(last_seen_at: nil, reference_time: Time.current)
      CodeSunset::StatusEngine.new(feature: self, last_seen_at: last_seen_at, reference_time: reference_time).status
    end

    def removal_score(snapshot = nil)
      snapshot ||= CodeSunset::FeatureQuery.new({}, scope: self.class.where(id: id)).call.first
      CodeSunset::ScoreCalculator.new(feature: self, snapshot: snapshot).score
    end

    private

    def apply_defaults
      self.sunset_after_days = 90 if sunset_after_days.blank?
      self.remove_after_days_unused = 60 if remove_after_days_unused.blank?
    end
  end
end
