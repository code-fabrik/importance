require "roo"
require "csv"

module Importance
  class ImportsController < ApplicationController
    # Form submission target. Persist the file and redirect to the mapping page.
    def submit
      upload = params[:file]

      raise ArgumentError, "Upload cannot be nil" if upload.nil?

      upload_extension = File.extname(upload.original_filename).downcase
      supported_extensions = [ ".xlsx", ".xls", ".csv" ]

      raise ArgumentError, "Unsupported file format. Please upload Excel (.xlsx, .xls) or CSV (.csv) files." unless supported_extensions.include?(upload_extension)

      system_tmp_dir = Dir.tmpdir
      upload_path = upload.tempfile.path
      persist_filename = "#{SecureRandom.uuid}#{upload_extension}"

      persist_path =  File.join(system_tmp_dir, persist_filename)

      raise ArgumentError, "File does not exist at #{upload_path}" if !File.exist?(upload_path)

      FileUtils.mv(upload_path, persist_path)

      session[:path] = persist_path
      session[:importer] = params[:importer].to_sym

      redirect_to map_path
    end

    # Mapping page. Load headers and samples, display the form.
    def map
      importer = Importance.configuration.importers[session[:importer].to_sym]

      raise ArgumentError, "Importer cannot be nil" if importer.nil?

      workbook = Roo::Spreadsheet.open(session[:path], { csv_options: { encoding: "bom|utf-8" } })
      worksheet = workbook.sheet(0)
      @file_headers = worksheet.row(1)
      @samples = worksheet.parse[1..5]
      @full_count = worksheet.count - 1

      @importer_attributes = importer.attributes
      @layout = "Importance::#{Importance.configuration.layout.to_s.camelize}Layout".constantize
    end

    # Import page. Load the file according to the mapping and import it.
    # Mappings param is of the form mappings[excel_column_idx] = target_attribute
    # mappings[0] = "first_name", mappings[1] = "", mappings[2] = "last_name" ...
    def import
      importer = Importance.configuration.importers[session[:importer].to_sym]
      mappings = params[:mappings]

      raise ArgumentError, "Mapping cannot be nil" if mappings.nil?

      if importer.setup_callback
        instance_exec(&importer.setup_callback)
      end

      begin
        records_to_import = []

        each_processed_row(mappings) do |record|
          records_to_import << record

          if importer.batch && records_to_import.size >= importer.batch
            instance_exec(records_to_import, &importer.perform_callback)
            records_to_import = []
          end
        end

        if records_to_import.any?
          instance_exec(records_to_import, &importer.perform_callback)
        end

        if importer.teardown_callback
          instance_exec(&importer.teardown_callback)
        else
          redirect_to session[:redirect_url] || root_path, notice: "Import completed."
        end

      rescue => e
        if importer.error_callback
          instance_exec(e, &importer.error_callback)
        end
      end
    end

    private

    def csv_file?
      File.extname(session[:path]).downcase == ".csv"
    end

    # Yields each processed row (a hash of attribute => value) to the given block.
    # Skips empty rows (all values nil or empty).
    def each_processed_row(mappings)
      workbook = Roo::Spreadsheet.open(session[:path], { csv_options: { encoding: "bom|utf-8" } })
      worksheet = workbook.sheet(0)
      worksheet.each_with_index do |row, idx|
        next if idx == 0 # Skip header row
        record = process_row(row, mappings)
        next if record.empty? || record.values.all? { |v| v.nil? || v.to_s.strip.empty? }
        yield record
      end
    end

    # Turn a row of the form ["Hans", "Robert", 1970, "male", "Apple Inc.", "hr@apple.com"]
    # and a mapping of the form {"0"=>"first_name", "1"=>"last_name", "2"=>"", "3"=>"", "4"=>"", "5"=>"email"}
    # into a record of the form { first_name: "Hans", last_name: "Robert", email: "hr@apple.com" }
    def process_row(row, mappings)
      record = {}

      mappings.each do |column_index, attribute_name|
        next if attribute_name.nil? || attribute_name == ""
        value = row[column_index.to_i]
        record[attribute_name.to_sym] = value
      end

      record
    end

    def rails_routes
      ::Rails.application.routes.url_helpers
    end
  end
end
