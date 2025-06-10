require "test_helper"

class NavigationTest < ActionDispatch::IntegrationTest
  include Importance::Engine.routes.url_helpers

  setup do
    Importance.configure do |config|
      config.set_layout(:blank) # Reset to default layout
      config.register_importer(:integration_test_importer) do
        attribute :name, [ "Name" ]
        attribute :email, [ "Email" ]
        perform do |records|
          # Simple test importer that just stores records
        end
      end
    end
  end

  test "full import workflow integration" do
    # Step 1: Submit file
    file = fixture_file_upload("test_import.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    post submit_path, params: { file: file, importer: "integration_test_importer" }

    assert_response :redirect
    assert_redirected_to map_path

    # Step 2: Visit mapping page
    follow_redirect!
    assert_response :success
    assert_select "table.importance-table"

    # Step 3: Submit mapping and import
    mappings = { "name" => "name", "email" => "email" }
    post import_path, params: { mappings: mappings }

    # Should complete successfully
    assert_includes [ 200, 204, 302 ], response.status
  end

  test "handles missing session data gracefully" do
    # Try to access map page without submitting file first
    # This should raise an error due to missing session data
    assert_raises do
      get map_path
    end
  end

  test "routes are accessible" do
    # Test that the routes exist by checking they respond
    assert_nothing_raised do
      app.routes.recognize_path("/importance/submit", method: :post)
      app.routes.recognize_path("/importance/map", method: :get)
      app.routes.recognize_path("/importance/import", method: :post)
    end
  end

  test "file upload form accepts correct file types" do
    file = fixture_file_upload("test_import.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")

    assert_nothing_raised do
      post submit_path, params: { file: file, importer: "integration_test_importer" }
    end
  end

  test "session persistence across requests" do
    file = fixture_file_upload("test_import.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    post submit_path, params: { file: file, importer: "integration_test_importer" }

    # Session should contain our data
    assert session[:path].present?
    assert_equal :integration_test_importer, session[:importer]

    # Following request should have access to session data
    get map_path
    assert_response :success
  end
end
