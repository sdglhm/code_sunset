module CodeSunset
  class EventPayload
    class << self
      def build(feature_key, attrs = {})
        return unless CodeSunset.enabled?

        key = feature_key.to_s.strip
        return if key.blank?
        return if sampled_out?

        merged = merge_context(attrs)
        metadata = merged.delete(:metadata).to_h.deep_symbolize_keys
        org_id = merged[:org_id]
        user_id = merged[:user_id]

        {
          feature_key: key,
          occurred_at: (merged[:occurred_at] || Time.current).utc,
          user_id: resolve(:user_resolver, user_id, metadata, merged) || user_id,
          org_id: resolve(:org_resolver, org_id, metadata, merged) || org_id,
          request_id: merged[:request_id],
          metadata: metadata,
          source: merged[:source].presence || infer_source(merged),
          request_path: merged[:request_path],
          controller: merged[:controller],
          action: merged[:action],
          job_class: merged[:job_class],
          app_env: merged[:app_env].presence || CodeSunset.configuration.environment,
          app_version: merged[:app_version].presence || CodeSunset.configuration.app_version,
          plan: merged[:plan].presence || resolve(:plan_resolver, org_id, metadata, merged),
          internal_org: coerce_boolean(merged.fetch(:internal_org, resolve(:internal_org_resolver, org_id, metadata, merged))),
          paid_org: coerce_boolean(merged.fetch(:paid_org, resolve(:paid_org_resolver, org_id, metadata, merged)))
        }.compact
      end

      private

      def merge_context(attrs)
        context = CodeSunset::Context.current
        normalized = attrs.to_h.symbolize_keys
        context.deep_merge(normalized) do |key, left_value, right_value|
          key == :metadata ? left_value.to_h.merge(right_value.to_h) : right_value
        end
      end

      def sampled_out?
        sample_rate = CodeSunset.configuration.sample_rate.to_f
        sample_rate < 1.0 && rand >= sample_rate
      end

      def resolve(name, *args)
        resolver = CodeSunset.configuration.public_send(name)
        return unless resolver.respond_to?(:call)

        CodeSunset.safe_execute("resolver #{name}") do
          case resolver.arity
          when 1 then resolver.call(args[0])
          when 2 then resolver.call(args[0], args[1])
          else resolver.call(*args)
          end
        end
      end

      def infer_source(payload)
        return "job" if payload[:job_class].present?
        return "request" if payload[:request_path].present?

        "manual"
      end

      def coerce_boolean(value)
        return if value.nil?
        return value if value == true || value == false

        ActiveModel::Type::Boolean.new.cast(value)
      end
    end
  end
end
