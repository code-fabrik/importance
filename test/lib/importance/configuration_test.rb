require "test_helper"

module Importance
  class ConfigurationTest < ActiveSupport::TestCase
    setup do
      @config = Configuration.new
    end

    test "initializes with empty importers hash and blank layout" do
      assert_equal({}, @config.importers)
      assert_equal(:blank, @config.layout)
    end

    test "can set layout" do
      @config.set_layout(:bootstrap)
      assert_equal(:bootstrap, @config.layout)
    end

    test "can register importer" do
      @config.register_importer(:test) do
        attribute :name, [ "Name" ]
      end

      assert @config.importers.key?(:test)
      assert_instance_of Importer, @config.importers[:test]
    end

    test "module level configuration" do
      Importance.configure do |config|
        config.set_layout(:custom)
        config.register_importer(:module_test) do
          attribute :email, [ "Email" ]
        end
      end

      assert_equal(:custom, Importance.configuration.layout)
      assert Importance.configuration.importers.key?(:module_test)
    end

    test "config alias works" do
      assert_equal Importance.configuration, Importance.config
    end
  end
end
