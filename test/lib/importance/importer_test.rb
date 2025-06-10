require "test_helper"

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
  end
end
