module CodeSunset
  class CleanupEventsJob < ApplicationJob
    queue_as :default

    def perform
      cutoff = CodeSunset.configuration.event_retention_days.days.ago
      CodeSunset::Event.where("occurred_at < ?", cutoff).delete_all
    end
  end
end
