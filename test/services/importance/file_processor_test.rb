require "test_helper"
require "csv"
require "tempfile"

module Importance
  class FileProcessorTest < ActiveSupport::TestCase
    test "processes CSV files correctly" do
      csv_content = "Name,Email\nJohn Doe,john@example.com\nJane Smith,jane@example.com"
      csv_file = Tempfile.new([ "test", ".csv" ])
      csv_file.write(csv_content)
      csv_file.rewind

      headers = []
      samples = []

      CSV.foreach(csv_file.path, headers: true) do |row|
        headers = row.headers if headers.empty?
        samples << row.to_h if samples.length < 5
      end

      assert_equal [ "Name", "Email" ], headers
      assert_equal 2, samples.length
      assert_equal "John Doe", samples[0]["Name"]
      assert_equal "john@example.com", samples[0]["Email"]

      csv_file.close
      csv_file.unlink
    end

    test "handles empty CSV files" do
      csv_content = "Name,Email\n"
      csv_file = Tempfile.new([ "test", ".csv" ])
      csv_file.write(csv_content)
      csv_file.rewind

      csv_data = CSV.read(csv_file.path, headers: true)
      headers = csv_data.headers
      samples = csv_data.first(5).map(&:to_h)

      assert_equal [ "Name", "Email" ], headers
      assert_equal 0, samples.length

      csv_file.close
      csv_file.unlink
    end

    test "handles CSV with special characters" do
      csv_content = "Name,Email\n\"Doe, John\",\"john@example.com\"\n\"Smith; Jane\",\"jane@test.com\""
      csv_file = Tempfile.new([ "test", ".csv" ])
      csv_file.write(csv_content)
      csv_file.rewind

      headers = []
      samples = []

      CSV.foreach(csv_file.path, headers: true) do |row|
        headers = row.headers if headers.empty?
        samples << row.to_h if samples.length < 5
      end

      assert_equal [ "Name", "Email" ], headers
      assert_equal 2, samples.length
      assert_equal "Doe, John", samples[0]["Name"]
      assert_equal "Smith; Jane", samples[1]["Name"]

      csv_file.close
      csv_file.unlink
    end

    test "processes row mappings correctly" do
      row_data = { "Full Name" => "John Doe", "Email Address" => "john@example.com", "Phone" => "555-1234" }
      mappings = ActionController::Parameters.new({
        "Full Name" => "name",
        "Email Address" => "email",
        "Phone" => ""  # Unmapped field
      })

      record = {}
      row_data.each do |row_header, value|
        attribute = mappings.permit!.to_h.find { |column_name, attribute_name| column_name == row_header }
        next if attribute.nil?
        attribute = attribute[1]
        next if attribute.nil? || attribute == ""
        record[attribute.to_sym] = value
      end

      assert_equal "John Doe", record[:name]
      assert_equal "john@example.com", record[:email]
      assert_nil record[:phone] # Should be nil since Phone is unmapped
    end

    test "filters out empty records" do
      test_records = [
        { name: "John", email: "john@example.com" },
        { name: "", email: "" },
        { name: nil, email: nil },
        { name: "  ", email: "  " },
        { name: "Jane", email: "jane@example.com" }
      ]

      filtered_records = test_records.reject do |record|
        record.empty? || record.values.all? { |v| v.nil? || v.to_s.strip.empty? }
      end

      assert_equal 2, filtered_records.length
      assert_equal "John", filtered_records[0][:name]
      assert_equal "Jane", filtered_records[1][:name]
    end

    test "handles mixed data types in records" do
      row_data = { "Name" => "John", "Age" => "25", "Active" => "true", "Score" => "95.5" }
      mappings = ActionController::Parameters.new({
        "Name" => "name",
        "Age" => "age",
        "Active" => "active",
        "Score" => "score"
      })

      record = {}
      row_data.each do |row_header, value|
        attribute = mappings.permit!.to_h.find { |column_name, attribute_name| column_name == row_header }
        next if attribute.nil?
        attribute = attribute[1]
        next if attribute.nil? || attribute == ""
        record[attribute.to_sym] = value
      end

      assert_equal "John", record[:name]
      assert_equal "25", record[:age]
      assert_equal "true", record[:active]
      assert_equal "95.5", record[:score]
    end
  end
end
