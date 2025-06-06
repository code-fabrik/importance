require "xsv"

module Importance
  class ImportsController < ApplicationController
    # Form submission target. Persist the file and redirect to the mapping page.
    def submit
      upload = params[:file]

      raise ArgumentError, "Upload cannot be nil" if upload.nil?

      system_tmp_dir = Dir.tmpdir
      upload_path = upload.tempfile.path
      upload_extension = File.extname(upload.original_filename)
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

      workbook = Xsv.open(session[:path], parse_headers: true)
      worksheet = workbook.first

      file_headers = worksheet.first.keys
      @file_headers = file_headers
      @importer_attributes = importer.attributes
      @samples = worksheet.first(5)

      @layout = "Importance::#{Importance.configuration.layout.to_s.camelize}Layout".constantize
    end

    # Import page. Load the file according to the mapping and import it.
    def import
      importer = Importance.configuration.importers[session[:importer].to_sym]
      mappings = params[:mappings]

      raise ArgumentError, "Mapping cannot be nil" if mappings.nil?

      workbook = Xsv.open(session[:path], parse_headers: true)
      worksheet = workbook.first

      if importer.setup_callback
        instance_exec(&importer.setup_callback)
      end

      begin
        records_to_import = []

        worksheet.each_with_index do |row, index|
          record = {}
          row.each do |row_header, value|
            attribute = mappings.permit!.to_h.find { |column_name, attribute_name| column_name == row_header }
            next if attribute.nil?
            attribute = attribute[1]
            next if attribute.nil? || attribute == ""
            record[attribute.to_sym] = value
          end

          # Skip empty rows (rows where all values are nil or empty)
          next if record.empty? || record.values.all? { |v| v.nil? || v.to_s.strip.empty? }

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

    def rails_routes
      ::Rails.application.routes.url_helpers
    end
  end
end
