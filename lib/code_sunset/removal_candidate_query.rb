module CodeSunset
  class RemovalCandidateQuery
    def initialize(filters = {})
      @filters = filters
    end

    def call
      CodeSunset::FeatureQuery.new(filters).call.select do |snapshot|
        %w[candidate_for_removal safe_to_remove].include?(snapshot.status)
      end.sort_by { |snapshot| [-snapshot.score.to_f, snapshot.feature.key] }
    end

    private

    attr_reader :filters
  end
end
