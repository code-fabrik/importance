require "test_helper"

module Importance
  class ImportsControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      # Records the :test_importer received, for verification
      @imported_records = []
      imported = @imported_records

      # Configure a test importer using the sample XLSX file structure
      Importance.configure do |config|
        config.set_layout(:blank) # Reset to default layout
        config.register_importer(:test_importer) do
          attribute :name, [ "Name" ]
          attribute :email, [ "Email" ]
          perform { |records| imported.concat(records) }
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

    test "submit should redirect with an alert when file is nil" do
      post submit_path, params: { importer: "test_importer" }

      assert_response :redirect
      assert_equal I18n.t("importance.errors.no_file"), flash[:alert]
    end

    test "submit falls back to the root path when no redirect_url was given" do
      post submit_path, params: { importer: "test_importer" }

      assert_redirected_to main_app.root_path
    end

    test "submit redirects to the given redirect_url on error" do
      post submit_path, params: { importer: "test_importer", redirect_url: "/students" }

      assert_redirected_to "/students"
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

      # Define column mappings from XLSX column index to importer attributes
      mappings = {
        "0" => "name",   # Map column 0 ("name") to the :name attribute
        "1" => "email"   # Map column 1 ("email") to the :email attribute
      }

      # Process the import
      assert_nothing_raised do
        post import_path, params: { mappings: mappings }
      end

      # Import should complete successfully
      assert_response :redirect
      assert_equal 2, @imported_records.size
      assert_equal({ name: "John Doe", email: "john@example.com" }, @imported_records.first)
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

      mappings = { "0" => "name", "1" => "email" }

      assert_nothing_raised do
        post import_path, params: { mappings: mappings }
      end

      assert_response :redirect
      assert_equal I18n.t("importance.success.import_completed"), flash[:notice]
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

      mappings = { "0" => "name" }
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

      mappings = { "0" => "name" }
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

      mappings = { "0" => "name" }
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

      mappings = { "0" => "name" }

      assert_nothing_raised do
        post import_path, params: { mappings: mappings }
      end

      assert error_handled
      assert_equal "Test error", error_message
    end

    # --- multiple attributes ---

    test "import maps several columns onto one multiple attribute" do
      processed_records = []

      Importance.configure do |config|
        config.register_importer(:location_importer) do
          attribute :name, [ "Name" ]
          attribute :location, [ "Standort" ], multiple: true
          perform { |records| processed_records.concat(records) }
        end
      end

      post submit_path, params: { file: locations_file, importer: "location_importer" }
      post import_path, params: { mappings: { "0" => "name", "1" => "location", "2" => "location", "3" => "location", "4" => "location" } }

      assert_equal 2, processed_records.size
      assert_equal "MTP-4711", processed_records.first[:name]
      assert_equal({ "WEIS" => "10", "LUBO1" => "10", "LUBO2" => "80", "LOCH" => "0" },
                   processed_records.first[:location])
    end

    test "import still rejects two columns mapped to a non-multiple attribute" do
      Importance.configure do |config|
        config.register_importer(:single_name_importer) do
          attribute :name, [ "Name" ]
          perform { |records| }
        end
      end

      post submit_path, params: { file: locations_file, importer: "single_name_importer" }
      post import_path, params: { mappings: { "0" => "name", "1" => "name" } }

      assert_response :unprocessable_entity
      assert_equal I18n.t("importance.errors.duplicate_mapping", attribute: "Name"), flash[:alert]
    end

    test "import requires at least one column for a non-optional multiple attribute" do
      Importance.configure do |config|
        config.register_importer(:required_location_importer) do
          attribute :name, [ "Name" ]
          attribute :location, [ "Standort" ], multiple: true
          perform { |records| }
        end
      end

      post submit_path, params: { file: locations_file, importer: "required_location_importer" }
      post import_path, params: { mappings: { "0" => "name", "1" => "", "2" => "", "3" => "", "4" => "" } }

      assert_response :unprocessable_entity
      assert_equal I18n.t("importance.errors.missing_mapping", attribute: "Standort"), flash[:alert]
    end

    test "import accepts a single column for a multiple attribute" do
      processed_records = []

      Importance.configure do |config|
        config.register_importer(:one_location_importer) do
          attribute :name, [ "Name" ]
          attribute :location, [ "Standort" ], multiple: true
          perform { |records| processed_records.concat(records) }
        end
      end

      post submit_path, params: { file: locations_file, importer: "one_location_importer" }
      post import_path, params: { mappings: { "0" => "name", "1" => "location", "2" => "", "3" => "", "4" => "" } }

      assert_equal 2, processed_records.size
      assert_equal({ "WEIS" => "10" }, processed_records.first[:location])
    end

    test "map page marks multiple attributes in the dropdown" do
      Importance.configure do |config|
        config.register_importer(:marked_importer) do
          attribute :name, [ "Name" ]
          attribute :location, [ "Standort" ], multiple: true
          perform { |records| }
        end
      end

      post submit_path, params: { file: locations_file, importer: "marked_importer" }
      get map_path

      assert_response :success
      assert_select "thead tr:first-child th:first-child select option",
                    text: I18n.t("importance.multiple_label", attribute: "Standort")
    end

    def locations_file
      fixture_file_upload("test_import_locations.csv", "text/csv")
    end

    teardown do
      # Clean up any persisted temporary files
      if @request && @request.session[:path] && File.exist?(@request.session[:path])
        File.delete(@request.session[:path])
      end
    end
  end
end
