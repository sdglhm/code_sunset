ENV["RAILS_ENV"] ||= "test"

require File.expand_path("../spec/dummy/config/environment", __dir__)
require "rails/test_help"

class ActiveSupport::TestCase
  include ActiveJob::TestHelper

  parallelize(workers: 1)

  setup do
    clear_enqueued_jobs
    clear_performed_jobs
    CodeSunset.reset_configuration!
    CodeSunset.event_buffer.drain
    CodeSunset.configure do |config|
      config.dashboard_authorizer = ->(_controller) { true }
    end
    ActiveJob::Base.queue_adapter = :test
  end
end
