module CodeSunset
  class FlushBufferedEventsJob < ApplicationJob
    queue_as :default

    def perform(limit: nil)
      CodeSunset::EventIngestor.flush_buffer(limit: limit)
    end
  end
end
