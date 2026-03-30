module CodeSunset
  class RemovalCandidatesController < ApplicationController
    def index
      @summaries = CodeSunset::RemovalCandidateQuery.new(filters).call
      @safe = @summaries.select { |summary| summary.status == "safe_to_remove" }
      @candidates = @summaries.select { |summary| summary.status == "candidate_for_removal" }
    end
  end
end
