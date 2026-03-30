require "test_helper"

class CodeSunsetGemspecTest < ActiveSupport::TestCase
  test "release manifest excludes development-only paths" do
    gemspec = Gem::Specification.load(File.expand_path("../../code_sunset.gemspec", __dir__))

    assert gemspec.files.none? { |path| path.start_with?("spec/") }
    assert gemspec.files.none? { |path| path.start_with?("test/") }
    assert gemspec.files.none? { |path| path.include?("spec/dummy/log") || path.include?("spec/dummy/tmp") }
  end
end
