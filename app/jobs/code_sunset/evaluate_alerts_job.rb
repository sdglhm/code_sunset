module CodeSunset
  class EvaluateAlertsJob < ApplicationJob
    queue_as :default

    def perform(feature_key = nil)
      if feature_key.present?
        CodeSunset::AlertDispatcher.new(feature_key).dispatch_if_due
      else
        CodeSunset::Feature.find_each do |feature|
          CodeSunset::AlertDispatcher.new(feature.key).dispatch_if_due
        end
      end
    end
  end
end
