module CodeSunset
  class Instrumentation
    EVENT_NAME = "code_sunset.hit".freeze

    class << self
      def hit(feature_key, **attrs)
        payload = CodeSunset::EventPayload.build(feature_key, attrs)
        return unless payload

        ActiveSupport::Notifications.instrument(EVENT_NAME, payload)
      rescue StandardError => error
        CodeSunset.log_error("instrumentation", error)
        nil
      end
    end
  end
end
