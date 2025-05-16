module Importance
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Creates an Importance initializer for your application"

      def copy_initializer
        template "importance.rb", "config/initializers/importance.rb"
      end

      def add_route
        route 'mount Importance::Engine, at: "/"'
      end

      def add_translations
        locale_files = Dir.glob(Rails.root.join("config", "locales", "*.yml"))

        if locale_files.empty?
          # If no locale files exist, create at least en.yml
          create_file "config/locales/en.yml", {
            en: {
              importance: {
                use_column_as: "Use column as",
                ignore: "Ignore",
                save: "Save"
              }
            }
          }.to_yaml
        else
          locale_files.each do |file|
            locale_content = YAML.load_file(file)
            locale_key = locale_content.keys.first

            # Add translations under the locale key
            if locale_content[locale_key].is_a?(Hash)
              locale_content[locale_key]["importance"] = {
                "use_column_as" => "Use column as",
                "ignore" => "Ignore",
                "save" => "Save"
              }

              # Write back to the file
              File.write(file, locale_content.to_yaml)
              say_status :insert, "importance translations into #{file}", :green
            end
          end
        end
      end
    end
  end
end
