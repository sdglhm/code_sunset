namespace :code_sunset do
  desc "Aggregate raw events into daily rollups"
  task aggregate_rollups: :environment do
    CodeSunset::AggregateDailyRollupsJob.perform_now
  end

  desc "Clean up raw events older than the configured retention window"
  task cleanup_events: :environment do
    CodeSunset::CleanupEventsJob.perform_now
  end

  desc "Evaluate alerts for deprecated features"
  task evaluate_alerts: :environment do
    CodeSunset::EvaluateAlertsJob.perform_now
  end

  desc "Flush buffered events when enqueue_failure_policy is :memory_buffer"
  task flush_buffer: :environment do
    CodeSunset::FlushBufferedEventsJob.perform_now
  end
end
