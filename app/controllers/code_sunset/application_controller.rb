module CodeSunset
  class ApplicationController < ActionController::Base
    layout "code_sunset/application"

    before_action :authorize_dashboard!
    helper_method :filters, :analytics_filters

    private

    def authorize_dashboard!
      authorizer = CodeSunset.configuration.dashboard_authorizer
      allowed = if authorizer.respond_to?(:call)
        authorizer.arity.zero? ? instance_exec(&authorizer) : authorizer.call(self)
      else
        false
      end

      return if allowed

      head :forbidden
    rescue StandardError => error
      CodeSunset.log_error("dashboard authorization", error)
      head :forbidden
    end

    def filters
      @filters ||= params.permit(*permitted_filter_keys).to_h.symbolize_keys
    end

    def analytics_filters
      @analytics_filters ||= CodeSunset::AnalyticsFilters.new(filters)
    end

    def permitted_filter_keys
      [
        :app_env,
        :plan,
        :org_id,
        :user_id,
        :from,
        :to,
        :paid_only,
        :exclude_internal,
        :window,
        :page,
        *CodeSunset.configuration.custom_filters.keys
      ]
    end
  end
end
