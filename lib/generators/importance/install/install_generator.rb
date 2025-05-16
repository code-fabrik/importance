module Importance
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Creates an Importance initializer for your application"

      def copy_initializer
        template "importance.rb", "config/initializers/importance.rb"
      end

      def show_readme
        readme "USAGE" if behavior == :invoke
      end
    end
  end
end
