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
      @worksheet = nil
      instance_eval(&block) if block_given?
    end

    def attribute(key, labels, options = {})
      @attributes << OpenStruct.new(key: key, labels: labels, options: options)
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

    def add_spreadsheet(path)
      workbook = Roo::Spreadsheet.open(path, { csv_options: { encoding: "bom|utf-8" } })
      @worksheet = workbook.sheet(0)
    end

    def file_headers
      @worksheet.row(1)
    end

    def samples
      @worksheet.parse[1..5]
    end

    def full_count
      @worksheet.count - 1
    end

    # Yields each processed row (a hash of attribute => value) to the given block.
    # Skips empty rows (all values nil or empty).
    def each_processed_row(path, mappings)
      @worksheet.each_with_index do |row, idx|
        next if idx == 0 # Skip header row
        record = process_row(row, mappings)
        next if record.empty? || record.values.all? { |v| v.nil? || v.to_s.strip.empty? }
        yield record
      end
    end

    # Turn a row of the form ["Hans", "Robert", 1970, "male", "Apple Inc.", "hr@apple.com"]
    # and a mapping of the form {"0"=>"first_name", "1"=>"last_name", "2"=>"", "3"=>"", "4"=>"", "5"=>"email"}
    # into a record of the form { first_name: "Hans", last_name: "Robert", email: "hr@apple.com" }
    def process_row(row, mappings)
      record = {}

      mappings.each do |column_index, attribute_name|
        next if attribute_name.nil? || attribute_name == ""
        value = row[column_index.to_i]
        record[attribute_name.to_sym] = value
      end

      record
    end
  end

  def self.configure
    yield(configuration)
  end

  def self.configuration
    @configuration ||= Configuration.new
  end
end
