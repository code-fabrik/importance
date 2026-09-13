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
      if options[:multiple] && Array(labels).empty?
        raise ArgumentError, "attribute #{key.inspect} is declared multiple: true but has no labels; " \
                             "labels are what the mapping dropdown and error messages display"
      end

      @multiple_keys = nil
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
      @file_headers = nil
    end

    def file_headers
      @file_headers ||= @worksheet.row(1)
    end

    def samples
      @worksheet.parse[1..5]
    end

    def full_count
      @worksheet.count - 1
    end

    def importer_attributes
      @attributes
    end

    # Keys (as strings) of the attributes declared with multiple: true.
    def multiple_keys
      @multiple_keys ||= @attributes.select { |attr| attr.options[:multiple] }.map { |attr| attr.key.to_s }
    end

    # Yields each processed row (a hash of attribute => value) to the given block.
    # Skips empty rows (all values nil or empty).
    def each_processed_row(path, mappings)
      @worksheet.each_with_index do |row, idx|
        next if idx == 0 # Skip header row
        record = process_row(row, mappings)
        next if record.empty?
        # A multiple attribute holds a hash, whose #to_s is never empty - look at its
        # values instead, or empty trailing rows would be imported.
        values = record.values.flat_map { |v| v.is_a?(Hash) ? v.values : [ v ] }
        next if values.all? { |v| v.nil? || v.to_s.strip.empty? }
        yield record
      end
    end

    # Turn a row of the form ["Hans", "Robert", 1970, "male", "Apple Inc.", "hr@apple.com"]
    # and a mapping of the form {"0"=>"first_name", "1"=>"last_name", "2"=>"", "3"=>"", "4"=>"", "5"=>"email"}
    # into a record of the form { first_name: "Hans", last_name: "Robert", email: "hr@apple.com" }
    #
    # Attributes declared with multiple: true may be mapped to any number of columns and
    # collect a hash of file header => value instead of a single value, e.g.
    # { location: { "WEIS" => 10, "LUBO1" => 80 } }.
    def process_row(row, mappings)
      record = {}

      mappings.each do |column_index, attribute_name|
        next if attribute_name.nil? || attribute_name == ""

        idx = column_index.to_i
        value = row[idx]

        if multiple_keys.include?(attribute_name.to_s)
          record[attribute_name.to_sym] ||= {}
          record[attribute_name.to_sym][header_name_for(idx)] = value
        else
          record[attribute_name.to_sym] = value
        end
      end

      record
    end

    private

    # The file header of a column, used as the key for multiple attributes. Columns with a
    # blank header fall back to a positional name so they never collide on a nil key.
    def header_name_for(column_index)
      name = file_headers[column_index].to_s.strip
      name.empty? ? "column_#{column_index + 1}" : name
    end
  end

  def self.configure
    yield(configuration)
  end

  def self.configuration
    @configuration ||= Configuration.new
  end
end
