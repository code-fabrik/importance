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
    attr_reader :name, :attributes, :callback, :batch

    def initialize(name, &block)
      @name = name
      @attributes = []
      @callback = nil
      @batch = false
      instance_eval(&block) if block_given?
    end

    def attribute(key, labels)
      @attributes << OpenStruct.new(key: key, labels: labels)
    end

    def batch_size(size)
      @batch = size
    end

    def on_complete(&callback)
      @callback = callback
    end
  end

  def self.configure
    yield(configuration)
  end

  def self.configuration
    @configuration ||= Configuration.new
  end
end
