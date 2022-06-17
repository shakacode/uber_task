# frozen_string_literal: true

require_relative "lib/uber_task/version"

Gem::Specification.new do |spec|
  spec.name = "uber_task"
  spec.version = UberTask::VERSION
  spec.authors = ["Justin Gordon"]
  spec.email = ["justin@shakacode.com"]

  spec.summary = "Running tasks"
  spec.description = "Longer description or delete this line."
  spec.homepage = "https://github.com/shakacode/uber_task"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/shakacode/uber_task"
  spec.metadata["changelog_uri"] = "https://github.com/shakacode/uber_task/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
