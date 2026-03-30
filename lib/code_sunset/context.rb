module CodeSunset
  class Context
    THREAD_KEY = :code_sunset_context_stack

    class << self
      def current
        stack.last.deep_dup
      end

      def push(context)
        stack << merge(current, normalize(context))
      end

      def pop
        stack.pop if stack.size > 1
        current
      end

      def with(context)
        push(context)
        yield
      ensure
        pop
      end

      private

      def stack
        Thread.current[THREAD_KEY] ||= [default_context]
      end

      def default_context
        { metadata: {} }
      end

      def normalize(context)
        context.to_h.symbolize_keys.tap do |normalized|
          normalized[:metadata] = normalized.fetch(:metadata, {}).to_h.deep_symbolize_keys
        end
      end

      def merge(left, right)
        left.deep_merge(right) do |key, left_value, right_value|
          key == :metadata ? left_value.to_h.merge(right_value.to_h) : right_value
        end
      end
    end
  end
end
