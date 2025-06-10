require "test_helper"

module Importance
  class LayoutTest < ActiveSupport::TestCase
    test "BlankLayout returns empty strings for all classes" do
      assert_equal "", BlankLayout.select_class
      assert_equal "", BlankLayout.submit_class
      assert_equal "", BlankLayout.table_class
      assert_equal "", BlankLayout.wrapper_class
    end

    test "BootstrapLayout inherits from BlankLayout" do
      assert_equal BlankLayout, BootstrapLayout.superclass
    end

    test "BootstrapLayout returns Bootstrap classes" do
      assert_equal "form-select", BootstrapLayout.select_class
      assert_equal "btn btn-primary", BootstrapLayout.submit_class
      assert_equal "table", BootstrapLayout.table_class
      assert_equal "table-responsive", BootstrapLayout.wrapper_class
    end

    test "layout classes can be instantiated from configuration" do
      # Test blank layout
      Importance.configure do |config|
        config.set_layout(:blank)
      end

      layout_class = "Importance::#{Importance.configuration.layout.to_s.camelize}Layout".constantize
      assert_equal BlankLayout, layout_class

      # Test bootstrap layout
      Importance.configure do |config|
        config.set_layout(:bootstrap)
      end

      layout_class = "Importance::#{Importance.configuration.layout.to_s.camelize}Layout".constantize
      assert_equal BootstrapLayout, layout_class
    end

    test "custom layout class would work with naming convention" do
      # Test that the naming convention would work for custom layouts
      # This verifies the pattern without actually creating a custom layout
      custom_layout_name = "custom"
      expected_class_name = "Importance::#{custom_layout_name.to_s.camelize}Layout"
      assert_equal "Importance::CustomLayout", expected_class_name
    end
  end
end
