CodeSunset.configure do |config|
  config.enabled = true
  config.environment = Rails.env
  config.async = true
  config.sample_rate = 1.0
  config.app_version = ENV["CODE_SUNSET_APP_VERSION"] || ENV["APP_VERSION"] || ENV["GIT_SHA"]
  config.identity_fields = %i[user_id org_id]
  config.hash_identity = false
  config.event_retention_days = 90
  config.enqueue_failure_policy = :drop
  config.enqueue_buffer_size = 1000
  config.alert_cooldown = 24.hours

  # Return true to allow dashboard access.
  config.dashboard_authorizer = ->(controller) { controller.respond_to?(:current_user) && controller.current_user.present? }

  # Optional business-domain hooks.
  # config.plan_resolver = ->(org_id, metadata, _payload) { metadata[:plan] }
  # config.internal_org_resolver = ->(org_id, _metadata, _payload) { InternalOrg.exists?(id: org_id) }
  # config.paid_org_resolver = ->(org_id, _metadata, _payload) { Account.find_by(id: org_id)&.paid? }

  # Optional custom metadata filters for the admin panel.
  # config.custom_filters = {
  #   region: { label: "Region", type: :string, metadata_key: "region" },
  #   beta_opt_in: { label: "Beta Opt-In", type: :boolean, metadata_key: "beta_opt_in" },
  #   account_tier: { label: "Account Tier", type: :select, metadata_key: "tier", options: [["Free", "free"], ["Pro", "pro"]] }
  # }
  # config.alert_webhook_url = ENV["CODE_SUNSET_WEBHOOK_URL"]
  # config.slack_webhook_url = ENV["CODE_SUNSET_SLACK_WEBHOOK_URL"]

  # Use :memory_buffer only for best-effort temporary queue outages.
  # Buffered events stay in-process and must be flushed by a scheduled job/task.
  # config.enqueue_failure_policy = :memory_buffer
end
