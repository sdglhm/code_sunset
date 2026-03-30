module CodeSunset
  class AggregateDailyRollupsJob < ApplicationJob
    queue_as :default

    def perform(start_date: nil, end_date: nil)
      range = normalize_range(start_date, end_date)
      relation = CodeSunset::Event.where(occurred_at: range)

      rows = relation
        .group(:feature_key, :app_env, Arel.sql("DATE(occurred_at)"))
        .pluck(
          :feature_key,
          :app_env,
          Arel.sql("DATE(occurred_at)"),
          Arel.sql("COUNT(*)"),
          Arel.sql("COUNT(DISTINCT #{CodeSunset::Event.user_identifier_expression})"),
          Arel.sql("COUNT(DISTINCT #{CodeSunset::Event.org_identifier_expression})"),
          Arel.sql("MAX(occurred_at)")
        )

      upserts = rows.map do |feature_key, app_env, day, hits_count, unique_users_count, unique_orgs_count, last_seen_at|
        {
          feature_key: feature_key,
          app_env: app_env,
          day: day,
          hits_count: hits_count,
          unique_users_count: unique_users_count,
          unique_orgs_count: unique_orgs_count,
          last_seen_at: last_seen_at,
          created_at: Time.current,
          updated_at: Time.current
        }
      end

      return if upserts.empty?

      CodeSunset::DailyRollup.upsert_all(upserts, unique_by: %i[feature_key app_env day])
    end

    private

    def normalize_range(start_date, end_date)
      from = start_date.present? ? Time.zone.parse(start_date.to_s).beginning_of_day : 30.days.ago.beginning_of_day
      to = end_date.present? ? Time.zone.parse(end_date.to_s).end_of_day : Time.current.end_of_day
      from..to
    end
  end
end
