require_relative "lib/importance/version"

Gem::Specification.new do |spec|
  spec.name        = "importance"
  spec.version     = Importance::VERSION
  spec.authors     = [ "Lukas_Skywalker" ]
  spec.email       = [ "git@lukasdiener.ch" ]
  spec.homepage    = "https://github.com/code-fabrik/importance"
  spec.summary     = "Flexible Excel and CSV import engine with column mapping for Rails applications"
  spec.description = "Importance is a Rails engine that allows users to upload Excel and CSV files and interactively map columns to model attributes. It handles files with arbitrary headers by letting users select which columns to import and which to ignore, with support for flexible attribute mapping, batch processing, error handling, and customizable import workflows."
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/code-fabrik/importance"
  spec.metadata["changelog_uri"] = "https://github.com/code-fabrik/importance"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 7.0.2"
  spec.add_dependency "xsv", "~> 1.3"
  spec.add_dependency "ostruct", "~> 0.6"
end
