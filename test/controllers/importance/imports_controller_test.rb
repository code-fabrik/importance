require "test_helper"

module Importance
  class ImportsControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      # Configure a test importer using the sample XLSX file structure
      Importance.configure do |config|
        config.register_importer(:test_importer) do
          attribute :name, ["Name"]
          attribute :email, ["Email"]
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
      assert_includes [204, 302], response.status
    end

    teardown do
      # Clean up any persisted temporary files
      if @request && @request.session[:path] && File.exist?(@request.session[:path])
        File.delete(@request.session[:path])
      end
    end
  end
end