require "test_helper"
require "roo"
require "tempfile"

module Importance
  class ImporterTest < ActiveSupport::TestCase
    test "initializes with name and empty attributes" do
      importer = Importer.new(:test)
      assert_equal(:test, importer.name)
      assert_equal([], importer.attributes)
      assert_nil importer.setup_callback
      assert_nil importer.perform_callback
      assert_nil importer.teardown_callback
      assert_nil importer.error_callback
      assert_equal false, importer.batch
    end

    test "can add attributes" do
      importer = Importer.new(:test) do
        attribute :name, [ "Name", "Full Name" ]
        attribute :email, [ "Email", "Email Address" ]
      end

      assert_equal 2, importer.attributes.length
      assert_equal :name, importer.attributes[0].key
      assert_equal [ "Name", "Full Name" ], importer.attributes[0].labels
      assert_equal :email, importer.attributes[1].key
      assert_equal [ "Email", "Email Address" ], importer.attributes[1].labels
    end

    test "can set batch size" do
      importer = Importer.new(:test) do
        batch_size 100
      end

      assert_equal 100, importer.batch
    end

    test "can set callbacks" do
      setup_called = false
      perform_called = false
      teardown_called = false
      error_called = false

      importer = Importer.new(:test) do
        setup { setup_called = true }
        perform { perform_called = true }
        teardown { teardown_called = true }
        error { error_called = true }
      end

      assert_not_nil importer.setup_callback
      assert_not_nil importer.perform_callback
      assert_not_nil importer.teardown_callback
      assert_not_nil importer.error_callback

      importer.setup_callback.call
      importer.perform_callback.call
      importer.teardown_callback.call
      importer.error_callback.call

      assert setup_called
      assert perform_called
      assert teardown_called
      assert error_called
    end

    test "callbacks receive context" do
      records = [ { name: "Test" } ]
      context = nil

      importer = Importer.new(:test) do
        perform do |data|
          context = data
        end
      end

      importer.perform_callback.call(records)
      assert_equal records, context
    end

    test "can add multiple attributes" do
      importer = Importer.new(:test) do
        attribute :name, [ "Name" ]
        attribute :location, [ "Standort", "Location" ], multiple: true
      end

      assert_equal [ "location" ], importer.multiple_keys
      assert_equal true, importer.attributes[1].options[:multiple]
    end

    test "rejects a multiple attribute without labels" do
      error = assert_raises(ArgumentError) do
        Importer.new(:test) do
          attribute :location, [], multiple: true
        end
      end

      assert_match(/multiple/, error.message)
    end

    # --- process_row / each_processed_row with multiple attributes ---

    test "process_row collects several columns of a multiple attribute keyed by header" do
      importer = importer_for(<<~CSV)
        Name,WEIS,LUBO1,LUBO2
        MTP-4711,10,10,80
      CSV

      record = importer.process_row([ "MTP-4711", 10, 10, 80 ], mappings("name", "location", "location", "location"))

      assert_equal({ "WEIS" => 10, "LUBO1" => 10, "LUBO2" => 80 }, record[:location])
    end

    test "process_row keeps non-multiple attributes scalar alongside a multiple attribute" do
      importer = importer_for(<<~CSV)
        Name,WEIS,LUBO1
        MTP-4711,10,90
      CSV

      record = importer.process_row([ "MTP-4711", 10, 90 ], mappings("name", "location", "location"))

      assert_equal "MTP-4711", record[:name]
      assert_equal({ "WEIS" => 10, "LUBO1" => 90 }, record[:location])
    end

    test "process_row preserves the column order of the file" do
      importer = importer_for(<<~CSV)
        Name,WEIS,LUBO1,LUBO2,LOCH
        MTP-4711,10,10,80,0
      CSV

      record = importer.process_row([ "MTP-4711", 10, 10, 80, 0 ],
                                    mappings("name", "location", "location", "location", "location"))

      assert_equal [ "WEIS", "LUBO1", "LUBO2", "LOCH" ], record[:location].keys
    end

    test "process_row falls back to a positional key for a blank header" do
      importer = importer_for(<<~CSV)
        Name,WEIS,,LOCH
        MTP-4711,10,80,10
      CSV

      record = importer.process_row([ "MTP-4711", 10, 80, 10 ], mappings("name", "location", "location", "location"))

      assert_equal({ "WEIS" => 10, "column_3" => 80, "LOCH" => 10 }, record[:location])
    end

    test "process_row lets the last of two identically named columns win" do
      importer = importer_for(<<~CSV)
        Name,LOCH,LOCH
        MTP-4711,10,80
      CSV

      record = importer.process_row([ "MTP-4711", 10, 80 ], mappings("name", "location", "location"))

      assert_equal({ "LOCH" => 80 }, record[:location])
    end

    test "each_processed_row skips a trailing empty row with mapped multiple columns" do
      importer = importer_for(<<~CSV)
        Name,WEIS,LUBO1
        MTP-4711,10,90
        ,,
      CSV

      records = []
      importer.each_processed_row(nil, mappings("name", "location", "location")) { |record| records << record }

      assert_equal 1, records.size
      assert_equal "MTP-4711", records.first[:name]
    end

    test "each_processed_row keeps a row where only a multiple column has a value" do
      importer = importer_for(<<~CSV)
        Name,WEIS,LUBO1
        ,,90
      CSV

      records = []
      importer.each_processed_row(nil, mappings("name", "location", "location")) { |record| records << record }

      assert_equal 1, records.size
      assert_equal({ "WEIS" => nil, "LUBO1" => "90" }, records.first[:location])
    end

    test "process_row is unchanged for importers without multiple attributes" do
      importer = Importer.new(:test) do
        attribute :first_name, [ "Vorname" ]
        attribute :last_name, [ "Nachname" ]
      end

      record = importer.process_row([ "Hans", "Robert", 1970 ], { "0" => "first_name", "1" => "last_name", "2" => "" })

      assert_equal({ first_name: "Hans", last_name: "Robert" }, record)
    end

    private

    # An importer with a :name and a multiple :location attribute, backed by the given CSV.
    def importer_for(csv)
      file = Tempfile.new([ "importance_test", ".csv" ])
      file.write(csv)
      file.close
      @tempfiles ||= []
      @tempfiles << file

      importer = Importer.new(:test) do
        attribute :name, [ "Name" ]
        attribute :location, [ "Standort" ], multiple: true
      end
      importer.add_spreadsheet(file.path)
      importer
    end

    # Turn ("name", "location", "location") into {"0"=>"name", "1"=>"location", "2"=>"location"}
    def mappings(*attribute_names)
      attribute_names.each_with_index.map { |name, idx| [ idx.to_s, name ] }.to_h
    end
  end
end
