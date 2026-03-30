module CodeSunset
  class AlertDispatcher
    ALERT_KIND = "deprecated_usage".freeze

    def initialize(feature_key)
      @feature = CodeSunset::Feature.find_by(key: feature_key)
    end

    def dispatch_if_due
      return unless feature

      snapshot = CodeSunset::FeatureQuery.new({}, scope: CodeSunset::Feature.where(id: feature.id)).call.first
      return unless snapshot
      return unless alertable?(snapshot)
      return if recently_delivered?(snapshot)

      payload = build_payload(snapshot)
      notify_logger(payload)
      notify_webhook(payload)
      notify_slack(payload)
      record_delivery(snapshot, payload)
      payload
    end

    private

    attr_reader :feature

    def alertable?(snapshot)
      snapshot.status != "active" && snapshot.hits_7d.to_i.positive?
    end

    def build_payload(snapshot)
      sample_event = feature.events.recent_first.first

      {
        feature_key: feature.key,
        status: snapshot.status,
        last_seen_at: snapshot.last_seen_at,
        hits_7d: snapshot.hits_7d,
        hits_30d: snapshot.hits_30d,
        unique_orgs_count: snapshot.unique_orgs_count,
        unique_users_count: snapshot.unique_users_count,
        example_org: sample_event&.display_org_identifier,
        example_user: sample_event&.display_user_identifier
      }
    end

    def recently_delivered?(snapshot)
      CodeSunset::AlertDelivery.recent_for(
        feature_key: feature.key,
        status: snapshot.status,
        alert_kind: ALERT_KIND,
        since: CodeSunset.configuration.alert_cooldown.ago
      ).exists?
    end

    def record_delivery(snapshot, payload)
      CodeSunset::AlertDelivery.create!(
        feature_key: feature.key,
        status: snapshot.status,
        alert_kind: ALERT_KIND,
        delivered_at: Time.current,
        payload: payload
      )
    end

    def notify_logger(payload)
      CodeSunset.logger.warn("[code_sunset] alert #{payload.to_json}")
    end

    def notify_webhook(payload)
      proc_hook = CodeSunset.configuration.alert_webhook_proc
      if proc_hook.respond_to?(:call)
        CodeSunset.safe_execute("alert webhook proc") { proc_hook.call(payload) }
      elsif CodeSunset.configuration.alert_webhook_url.present?
        post_json(CodeSunset.configuration.alert_webhook_url, payload)
      end
    end

    def notify_slack(payload)
      return if CodeSunset.configuration.slack_webhook_url.blank?

      message = {
        text: "Feature #{payload[:feature_key]} is #{payload[:status]} and still saw #{payload[:hits_7d]} hits in the last 7 days across #{payload[:unique_orgs_count]} orgs."
      }
      post_json(CodeSunset.configuration.slack_webhook_url, message)
    end

    def post_json(url, payload)
      CodeSunset.safe_execute("alert post #{url}") do
        uri = URI.parse(url)
        request = Net::HTTP::Post.new(uri.request_uri)
        request["Content-Type"] = "application/json"
        request.body = payload.to_json

        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
          http.request(request)
        end
      end
    end
  end
end
