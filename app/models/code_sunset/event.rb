module CodeSunset
  class Event < ApplicationRecord
    self.table_name = "code_sunset_events"

    belongs_to :feature, primary_key: :key, foreign_key: :feature_key, inverse_of: :events, optional: true

    validates :feature_key, presence: true
    validates :occurred_at, presence: true

    before_validation :apply_defaults

    scope :recent_first, -> { order(occurred_at: :desc) }

    class << self
      def create_from_payload(payload)
        attrs = sanitize_payload(payload)

        transaction do
          CodeSunset::Feature.find_or_create_by!(key: attrs[:feature_key])
          create!(attrs)
        end
      end

      def apply_filters(filters = {})
        scoped = all
        normalized = filters.to_h.symbolize_keys

        scoped = scoped.where(app_env: normalized[:app_env]) if normalized[:app_env].present?
        scoped = scoped.where(plan: normalized[:plan]) if normalized[:plan].present?
        if normalized[:org_id].present?
          scoped = apply_identity_filter(scoped, :org_id, :hashed_org_id, normalized[:org_id])
        end
        if normalized[:user_id].present?
          scoped = apply_identity_filter(scoped, :user_id, :hashed_user_id, normalized[:user_id])
        end
        scoped = scoped.where(paid_org: true) if truthy?(normalized[:paid_only])
        scoped = scoped.where.not(internal_org: true) if truthy?(normalized[:exclude_internal])
        scoped = apply_custom_metadata_filters(scoped, normalized)

        from_time = parse_time(normalized[:from])&.beginning_of_day
        to_time = parse_time(normalized[:to])&.end_of_day

        scoped = scoped.where(occurred_at: from_time..) if from_time
        scoped = scoped.where(occurred_at: ..to_time) if to_time
        scoped
      end

      def grouped_last_seen(scope)
        scope.group(:feature_key).maximum(:occurred_at)
      end

      def grouped_counts(scope)
        scope.group(:feature_key).count
      end

      def grouped_distinct_org_counts(scope)
        scope.group(:feature_key).distinct.count(Arel.sql(org_identifier_expression))
      end

      def grouped_distinct_user_counts(scope)
        scope.group(:feature_key).distinct.count(Arel.sql(user_identifier_expression))
      end

      def top_request_paths(scope, limit: 10)
        grouped_top(scope.where.not(request_path: [nil, ""]), "request_path", limit: limit)
      end

      def top_job_classes(scope, limit: 10)
        grouped_top(scope.where.not(job_class: [nil, ""]), "job_class", limit: limit)
      end

      def top_orgs(scope, limit: 10)
        grouped_top(scope, org_identifier_expression, limit: limit, alias_name: "org_identifier")
      end

      def top_users(scope, limit: 10)
        grouped_top(scope, user_identifier_expression, limit: limit, alias_name: "user_identifier")
      end

      def org_identifier_expression
        "COALESCE(code_sunset_events.hashed_org_id, code_sunset_events.org_id::text)"
      end

      def user_identifier_expression
        "COALESCE(code_sunset_events.hashed_user_id, code_sunset_events.user_id::text)"
      end

      private

      def sanitize_payload(payload)
        attrs = payload.to_h.symbolize_keys.slice(
          :feature_key,
          :occurred_at,
          :user_id,
          :org_id,
          :request_id,
          :source,
          :request_path,
          :controller,
          :action,
          :job_class,
          :app_env,
          :app_version,
          :metadata,
          :plan,
          :internal_org,
          :paid_org
        )
        attrs[:metadata] = attrs.fetch(:metadata, {}).to_h

        if CodeSunset.configuration.hash_identity
          apply_identity_hash!(attrs, :user_id, :hashed_user_id)
          apply_identity_hash!(attrs, :org_id, :hashed_org_id)
        end

        attrs
      end

      def apply_identity_hash!(attrs, source_key, target_key)
        return unless CodeSunset.configuration.identity_fields.include?(source_key)
        return if attrs[source_key].blank?

        attrs[target_key] = CodeSunset::IdentityHash.digest(attrs[source_key])
        attrs[source_key] = nil
      end

      def grouped_top(scope, expression, limit:, alias_name: "identifier")
        scope
          .select("#{expression} AS #{alias_name}", "COUNT(*) AS hits")
          .where(Arel.sql("#{expression} IS NOT NULL"))
          .group(alias_name)
          .order("hits DESC")
          .limit(limit)
          .map { |row| [row.public_send(alias_name), row.hits.to_i] }
      end

      def apply_custom_metadata_filters(scope, filters)
        CodeSunset.configuration.custom_filters.each do |param_key, definition|
          next unless filters[param_key].present?

          metadata_key = definition[:metadata_key]
          case definition[:type].to_sym
          when :boolean
            scope = scope.where("code_sunset_events.metadata ->> ? = ?", metadata_key, truthy?(filters[param_key]).to_s)
          else
            scope = scope.where("code_sunset_events.metadata ->> ? = ?", metadata_key, filters[param_key].to_s)
          end
        end

        scope
      end

      def apply_identity_filter(scope, raw_key, hashed_key, value)
        if CodeSunset.configuration.hash_identity && CodeSunset.configuration.identity_fields.include?(raw_key)
          scope.where(hashed_key => CodeSunset::IdentityHash.digest(value))
        else
          scope.where(raw_key => value)
        end
      end

      def parse_time(value)
        return if value.blank?

        Time.zone.parse(value.to_s)
      rescue ArgumentError
        nil
      end

      def truthy?(value)
        ActiveModel::Type::Boolean.new.cast(value)
      end
    end

    def display_org_identifier
      hashed_org_id.presence || org_id&.to_s
    end

    def display_user_identifier
      hashed_user_id.presence || user_id&.to_s
    end

    private

    def apply_defaults
      self.app_env = CodeSunset.configuration.environment if app_env.blank?
      self.metadata = metadata.to_h if metadata.present?
      self.metadata ||= {}
    end
  end
end
