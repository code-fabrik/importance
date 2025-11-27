require "importance/version"
require "importance/engine"
require "importance/configuration"
require "generators/importance/install/install_generator" if defined?(Rails::Generators)

module Importance
  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    # Alias for YourImporterGemName.configuration
    def config
      configuration
    end

    # Yields the singleton configuration object to a block.
    # Used in the Rails initializer.
    def configure
      yield(configuration)
    end
  end
end
