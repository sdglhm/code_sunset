module CodeSunset
  module JobContext
    extend ActiveSupport::Concern

    included do
      around_perform :with_code_sunset_job_context
    end

    private

    def with_code_sunset_job_context
      CodeSunset.with_context(job_class: self.class.name, source: "job") do
        yield
      end
    end
  end
end
