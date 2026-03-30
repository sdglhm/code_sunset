module CodeSunset
  class Configuration
    attr_accessor :enabled,
      :environment,
      :async,
      :sample_rate,
      :app_version,
      :identity_fields,
      :hash_identity,
      :dashboard_authorizer,
      :org_resolver,
      :user_resolver,
      :plan_resolver,
      :internal_org_resolver,
      :paid_org_resolver,
      :alert_webhook_url,
      :alert_webhook_proc,
      :slack_webhook_url,
      :event_retention_days,
      :enqueue_failure_policy,
      :enqueue_buffer_size,
      :alert_cooldown

    def initialize
      @enabled = true
      @environment = defined?(Rails) ? Rails.env : ENV.fetch("RAILS_ENV", ENV.fetch("RACK_ENV", "development"))
      @async = true
      @sample_rate = 1.0
      @app_version = ENV["CODE_SUNSET_APP_VERSION"] || ENV["APP_VERSION"] || ENV["GIT_SHA"]
      @identity_fields = %i[user_id org_id]
      @hash_identity = false
      @dashboard_authorizer = nil
      @org_resolver = nil
      @user_resolver = nil
      @plan_resolver = nil
      @internal_org_resolver = nil
      @paid_org_resolver = nil
      @alert_webhook_url = nil
      @alert_webhook_proc = nil
      @slack_webhook_url = nil
      @event_retention_days = 90
      @enqueue_failure_policy = :drop
      @enqueue_buffer_size = 1000
      @alert_cooldown = 24.hours
      @custom_filters = {}
    end

    def sample_rate=(value)
      numeric = value.to_f
      @sample_rate = numeric.clamp(0.0, 1.0)
    end

    def identity_fields=(value)
      @identity_fields = Array(value).map(&:to_sym)
    end

    def enqueue_failure_policy=(value)
      @enqueue_failure_policy = (value || :drop).to_sym
    end

    def enqueue_buffer_size=(value)
      @enqueue_buffer_size = [value.to_i, 1].max
    end

    def alert_cooldown=(value)
      @alert_cooldown = value.is_a?(Numeric) ? value.seconds : value
    end

    def custom_filters
      @custom_filters ||= {}
    end

    def custom_filters=(value)
      @custom_filters = value.to_h.each_with_object({}) do |(key, definition), memo|
        next if definition.blank?

        normalized = definition.to_h.symbolize_keys
        memo[key.to_sym] = {
          label: normalized[:label].presence || key.to_s.humanize,
          type: (normalized[:type] || :string).to_sym,
          metadata_key: (normalized[:metadata_key] || key).to_s,
          options: normalize_filter_options(normalized[:options]),
          placeholder: normalized[:placeholder].presence
        }.compact
      end
    end

    private

    def normalize_filter_options(options)
      return unless options.present?

      Array(options).map do |option|
        if option.is_a?(Array)
          [option[0].to_s, option[1].to_s]
        elsif option.is_a?(Hash)
          [option[:label].to_s, option[:value].to_s]
        else
          [option.to_s.humanize, option.to_s]
        end
      end
    end
  end
end
