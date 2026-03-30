module CodeSunset
  class PersistEventJob < ApplicationJob
    queue_as :default

    def perform(payload)
      CodeSunset::Event.create_from_payload(payload)
    end
  end
end
