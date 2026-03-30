module CodeSunset
  class Subscriber
    class << self
      def subscribe!
        return @subscription if @subscription

        @subscription = ActiveSupport::Notifications.subscribe(CodeSunset::Instrumentation::EVENT_NAME) do |_name, _start, _finish, _id, payload|
          CodeSunset::EventIngestor.ingest(payload)
        end
      end

      def unsubscribe!
        return unless @subscription

        ActiveSupport::Notifications.unsubscribe(@subscription)
        @subscription = nil
      end

      def subscription
        @subscription
      end
    end
  end
end
