module CodeSunset
  class EventIngestor
    class << self
      def ingest(payload)
        return if payload.blank?

        if CodeSunset.configuration.async && defined?(CodeSunset::PersistEventJob)
          enqueue(payload)
        else
          persist(payload)
        end
      rescue StandardError => error
        CodeSunset.log_error("event ingestion", error)
        handle_async_failure(payload, error)
      end

      def persist(payload)
        return unless defined?(CodeSunset::Event)

        CodeSunset::Event.create_from_payload(payload)
      rescue StandardError => error
        CodeSunset.log_error("event persistence", error)
        nil
      end

      def flush_buffer(limit: nil)
        drained = CodeSunset.event_buffer.drain(limit: limit)
        drained.each { |payload| persist(payload) }
        drained.size
      rescue StandardError => error
        CodeSunset.log_error("buffer flush", error)
        0
      end

      private

      def enqueue(payload)
        CodeSunset::PersistEventJob.perform_later(payload)
      rescue StandardError => error
        CodeSunset.log_error("persist event job enqueue", error)
        handle_async_failure(payload, error)
      end

      def handle_async_failure(payload, _error)
        case CodeSunset.configuration.enqueue_failure_policy
        when :memory_buffer
          stored = CodeSunset.event_buffer.store(payload, limit: CodeSunset.configuration.enqueue_buffer_size)
          CodeSunset.logger.warn("[code_sunset] event buffer full, dropping payload for #{payload[:feature_key]}") unless stored
          stored
        else
          CodeSunset.logger.warn("[code_sunset] dropping payload after async enqueue failure for #{payload[:feature_key]}")
          nil
        end
      end
    end
  end
end
