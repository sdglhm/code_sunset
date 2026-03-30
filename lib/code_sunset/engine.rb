module CodeSunset
  class Engine < ::Rails::Engine
    isolate_namespace CodeSunset
    engine_name "code_sunset"

    config.generators do |g|
      g.test_framework :test_unit
    end

    initializer "code_sunset.controller_context" do
      ActiveSupport.on_load(:action_controller_base) do
        include CodeSunset::ControllerContext
      end

      ActiveSupport.on_load(:active_job) do
        include CodeSunset::JobContext
      end
    end

    config.after_initialize do
      CodeSunset::Subscriber.subscribe!
    end
  end
end
