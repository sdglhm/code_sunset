require_relative "lib/code_sunset/version"

Gem::Specification.new do |spec|
  spec.name        = "code_sunset"
  spec.version     = CodeSunset::VERSION
  spec.authors     = [ "sdglhm" ]
  spec.email       = [ "hello@sdglhm.com" ]
  spec.homepage    = "https://sdglhm.com"
  spec.summary     = "Runtime-aware deprecation intelligence for Rails."
  spec.description = "Track legacy code usage, aggregate removal signals, and review everything in a mounted Rails engine dashboard."
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/sdglhm/code_sunset"
  spec.metadata["changelog_uri"] = "https://github.com/sdglhm/code_sunset/blob/main/README.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/sdglhm/code_sunset/issues"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    tracked = `git ls-files -z 2>/dev/null`.split("\x0")
    tracked = Dir["app/**/*", "config/**/*", "db/**/*", "lib/**/*", "bin/*", "MIT-LICENSE", "Rakefile", "README.md", "*.gemspec"] if tracked.empty?
    tracked.select do |path|
      path.match?(%r{\A(app|config|db|lib)/}) ||
        path.match?(%r{\Abin/}) ||
        %w[MIT-LICENSE Rakefile README.md code_sunset.gemspec].include?(path)
    end
  end

  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 7.1", "< 9.0"

  spec.add_development_dependency "pg", "~> 1.6"
  spec.add_development_dependency "puma", "~> 7.0"
  spec.add_development_dependency "propshaft", ">= 1.0", "< 2.0"
end
