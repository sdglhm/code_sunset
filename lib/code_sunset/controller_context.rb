module CodeSunset
  module ControllerContext
    extend ActiveSupport::Concern

    included do
      around_action :with_code_sunset_request_context
    end

    private

    def with_code_sunset_request_context
      CodeSunset.with_context(
        request_id: request.request_id,
        request_path: request.fullpath,
        controller: controller_name,
        action: action_name,
        source: "request"
      ) do
        yield
      end
    end
  end
end
