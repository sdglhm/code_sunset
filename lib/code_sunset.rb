require "active_support"
require "active_support/core_ext/hash/deep_merge"
require "active_support/core_ext/hash/keys"
require "active_support/core_ext/integer/time"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/object/try"
require "digest"
require "json"
require "logger"
require "net/http"
require "uri"

require "code_sunset/version"
require "code_sunset/configuration"
require "code_sunset/context"
require "code_sunset/controller_context"
require "code_sunset/job_context"
require "code_sunset/event_buffer"
require "code_sunset/analytics_filters"
require "code_sunset/event_payload"
require "code_sunset/instrumentation"
require "code_sunset/event_ingestor"
require "code_sunset/identity_hash"
require "code_sunset/feature_snapshot"
require "code_sunset/status_engine"
require "code_sunset/score_calculator"
require "code_sunset/feature_query"
require "code_sunset/removal_candidate_query"
require "code_sunset/feature_usage_series"
require "code_sunset/removal_prompt_builder"
require "code_sunset/alert_dispatcher"
require "code_sunset/subscriber"
require "code_sunset/engine"

module CodeSunset
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    def enabled?
      configuration.enabled
    end

    def event_buffer
      @event_buffer ||= CodeSunset::EventBuffer.new
    end

    def hit(feature_key, **attrs)
      Instrumentation.hit(feature_key, **attrs)
    end

    def track(feature_key, **attrs)
      hit(feature_key, **attrs)
      return unless block_given?

      yield
    end

    def with_context(**context)
      return unless block_given?

      Context.with(context) { yield }
    end

    def register(feature_key, **attrs)
      return unless enabled?
      return unless defined?(CodeSunset::Feature)

      safe_execute("register #{feature_key}") do
        feature = CodeSunset::Feature.find_or_initialize_by(key: feature_key.to_s)
        feature.assign_attributes(attrs.compact)
        feature.save!
        feature
      end
    end

    def removal_candidates(filters = {})
      return [] unless defined?(CodeSunset::RemovalCandidateQuery)

      CodeSunset::RemovalCandidateQuery.new(filters).call
    end

    def logger
      return Rails.logger if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger

      @logger ||= Logger.new($stdout)
    end

    def log_error(message, error)
      logger.error("[code_sunset] #{message}: #{error.class}: #{error.message}")
    end

    def safe_execute(description = "operation")
      yield
    rescue StandardError => error
      log_error(description, error)
      nil
    end
  end
end
