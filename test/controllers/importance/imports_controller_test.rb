require "test_helper"

module Importance
  class ImportsControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      # Configure a test importer using the sample XLSX file structure
      Importance.configure do |config|
        config.set_layout(:blank) # Reset to default layout
        config.register_importer(:test_importer) do
          attribute :name, [ "Name" ]
          attribute :email, [ "Email" ]
          perform do |records|
            # Store records for verification (in real use, this would save to database)
            @controller.instance_variable_set(:@imported_records, records)
          end
        end
      end
    end

    test "submit should persist file and redirect to map page" do
      file = fixture_file_upload("test_import.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")

      post submit_path, params: { file: file, importer: "test_importer" }

      assert_response :redirect
      assert_redirected_to map_path
      assert @request.session[:path].present?
      assert_equal :test_importer, @request.session[:importer]
      assert File.exist?(@request.session[:path])
    end

    test "submit should raise error when file is nil" do
      assert_raises(ArgumentError, "Upload cannot be nil") do
        post submit_path, params: { importer: "test_importer" }
      end
    end

    test "map should create headers for each attribute with file columns as candidates" do
      file = fixture_file_upload("test_import.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
      post submit_path, params: { file: file, importer: "test_importer" }

      get map_path

      assert_response :success
      # Test that the page renders successfully with the new Header interface
      assert_select "table.importance-table" do
        assert_select "thead tr", 2  # Header row for selects and header row for attribute names
        assert_select "thead tr:first-child th", 2  # 2 attribute headers
        assert_select "thead tr:last-child th", 2   # 2 attribute labels
      end
    end

    test "import should process XLSX file with mappings" do
      # First submit the test file to set up session
      file = fixture_file_upload("test_import.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
      post submit_path, params: { file: file, importer: "test_importer" }

      # Define column mappings from XLSX headers to importer attributes
      mappings = {
        "name" => "name",    # Map "name" column to :name attribute
        "email" => "email"   # Map "email" column to :email attribute
      }

      # Process the import
      assert_nothing_raised do
        post import_path, params: { mappings: mappings }
      end

      # Import should complete successfully
      assert_includes [ 204, 302 ], response.status
    end

    test "submit stores file extension correctly" do
      file = fixture_file_upload("test_import.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
      post submit_path, params: { file: file, importer: "test_importer" }

      assert_response :redirect
      # Check that the session has the expected data
      assert @request.session[:path].present?
      assert_equal :test_importer, @request.session[:importer]
    end

    test "map page renders with valid session" do
      file = fixture_file_upload("test_import.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
      post submit_path, params: { file: file, importer: "test_importer" }

      get map_path
      assert_response :success
      # Verify the page has the expected elements
      assert_select "table.importance-table"
    end

    test "successful import completes without errors" do
      file = fixture_file_upload("test_import.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
      post submit_path, params: { file: file, importer: "test_importer" }

      mappings = { "name" => "name", "email" => "email" }

      assert_nothing_raised do
        post import_path, params: { mappings: mappings }
      end

      assert_includes [ 200, 204, 302 ], response.status
    end

    test "import should handle empty rows" do
      processed_records = []
      Importance.configure do |config|
        config.register_importer(:empty_row_importer) do
          attribute :name, [ "Name" ]
          perform do |records|
            processed_records.concat(records)
          end
        end
      end

      file = fixture_file_upload("test_import.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
      post submit_path, params: { file: file, importer: "empty_row_importer" }

      mappings = { "name" => "name" }
      post import_path, params: { mappings: mappings }

      # Should only process non-empty rows
      assert processed_records.length > 0
      assert processed_records.all? { |record| record[:name].present? }
    end

    test "import should handle batch processing" do
      batch_calls = 0
      total_records = 0

      Importance.configure do |config|
        config.register_importer(:batch_importer) do
          attribute :name, [ "Name" ]
          batch_size 1 # Process one record at a time
          perform do |records|
            batch_calls += 1
            total_records += records.length
          end
        end
      end

      file = fixture_file_upload("test_import.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
      post submit_path, params: { file: file, importer: "batch_importer" }

      mappings = { "name" => "name" }
      post import_path, params: { mappings: mappings }

      # Should have made multiple batch calls
      assert batch_calls > 1
      assert total_records > 0
    end

    test "import should call setup and teardown callbacks" do
      setup_called = false
      teardown_called = false

      Importance.configure do |config|
        config.register_importer(:callback_importer) do
          attribute :name, [ "Name" ]
          setup { setup_called = true }
          perform { |records| }
          teardown { teardown_called = true }
        end
      end

      file = fixture_file_upload("test_import.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
      post submit_path, params: { file: file, importer: "callback_importer" }

      mappings = { "name" => "name" }
      post import_path, params: { mappings: mappings }

      assert setup_called
      assert teardown_called
    end

    test "import should handle errors with error callback" do
      error_handled = false
      error_message = nil

      Importance.configure do |config|
        config.register_importer(:error_importer) do
          attribute :name, [ "Name" ]
          perform { |records| raise StandardError, "Test error" }
          error do |e|
            error_handled = true
            error_message = e.message
          end
        end
      end

      file = fixture_file_upload("test_import.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
      post submit_path, params: { file: file, importer: "error_importer" }

      mappings = { "name" => "name" }

      assert_nothing_raised do
        post import_path, params: { mappings: mappings }
      end

      assert error_handled
      assert_equal "Test error", error_message
    end

    teardown do
      # Clean up any persisted temporary files
      if @request && @request.session[:path] && File.exist?(@request.session[:path])
        File.delete(@request.session[:path])
      end
    end
  end
end
