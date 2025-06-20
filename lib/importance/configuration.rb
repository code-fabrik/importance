require "ostruct"

module Importance
  class Configuration
    attr_accessor :importers, :layout

    def initialize
      @importers = {}
      @layout = :blank
    end

    def register_importer(name, &block)
      @importers[name] = Importer.new(name, &block)
    end

    def set_layout(name)
      @layout = name
    end
  end

  class Importer
    attr_reader :name, :attributes, :batch, :setup_callback, :perform_callback, :teardown_callback, :error_callback

    def initialize(name, &block)
      @name = name
      @attributes = []
      @setup_callback = nil
      @perform_callback = nil
      @teardown_callback = nil
      @error_callback = nil
      @batch = false
      instance_eval(&block) if block_given?
    end

    def attribute(key, labels)
      @attributes << OpenStruct.new(key: key, labels: labels)
    end

    def batch_size(size)
      @batch = size
    end

    def setup(&block)
      @setup_callback = block
    end

    def perform(&block)
      @perform_callback = block
    end

    def teardown(&block)
      @teardown_callback = block
    end

    def error(&block)
      @error_callback = block
    end
  end

  def self.configure
    yield(configuration)
  end

  def self.configuration
    @configuration ||= Configuration.new
  end
end
