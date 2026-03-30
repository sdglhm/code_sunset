module CodeSunset
  class EventBuffer
    def initialize
      @payloads = []
      @mutex = Mutex.new
    end

    def store(payload, limit:)
      @mutex.synchronize do
        return false if @payloads.size >= limit

        @payloads << payload.deep_dup
        true
      end
    end

    def drain(limit: nil)
      @mutex.synchronize do
        count = limit ? [limit.to_i, 0].max : @payloads.size
        @payloads.shift(count)
      end
    end

    def size
      @mutex.synchronize { @payloads.size }
    end
  end
end
