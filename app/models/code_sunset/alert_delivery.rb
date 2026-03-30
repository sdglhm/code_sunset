module CodeSunset
  class AlertDelivery < ApplicationRecord
    self.table_name = "code_sunset_alert_deliveries"

    validates :feature_key, :status, :alert_kind, :delivered_at, presence: true

    class << self
      def recent_for(feature_key:, status:, alert_kind:, since:)
        where(feature_key: feature_key, status: status, alert_kind: alert_kind)
          .where("delivered_at >= ?", since)
      end
    end
  end
end
