module CodeSunset
  class DailyRollup < ApplicationRecord
    self.table_name = "code_sunset_daily_rollups"

    belongs_to :feature, primary_key: :key, foreign_key: :feature_key, inverse_of: :daily_rollups, optional: true

    validates :feature_key, :day, presence: true
    validates :feature_key, uniqueness: { scope: [:app_env, :day] }

    scope :ordered, -> { order(day: :asc) }

    class << self
      def apply_filters(filters = {})
        normalized = filters.to_h.symbolize_keys
        scoped = all
        scoped = scoped.where(app_env: normalized[:app_env]) if normalized[:app_env].present?
        scoped = scoped.where(day: parse_date(normalized[:from])..) if normalized[:from].present? && parse_date(normalized[:from])
        scoped = scoped.where(day: ..parse_date(normalized[:to])) if normalized[:to].present? && parse_date(normalized[:to])
        scoped
      end

      private

      def parse_date(value)
        Date.parse(value.to_s)
      rescue Date::Error
        nil
      end
    end
  end
end
