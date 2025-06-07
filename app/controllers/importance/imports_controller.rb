require "xsv"
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

      if csv_file?
        csv_data = CSV.read(session[:path], headers: true)
        @file_headers = csv_data.headers
        @samples = csv_data.first(5).map(&:to_h)
      else
        workbook = Xsv.open(session[:path], parse_headers: true)
        worksheet = workbook.first
        @file_headers = worksheet.first.keys
        @samples = worksheet.first(5)
      end

      @importer_attributes = importer.attributes
      @layout = "Importance::#{Importance.configuration.layout.to_s.camelize}Layout".constantize
    end

    # Import page. Load the file according to the mapping and import it.
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

    def each_processed_row(mappings)
      if csv_file?
        CSV.foreach(session[:path], headers: true) do |row|
          record = process_row(row.to_h, mappings)
          next if record.empty? || record.values.all? { |v| v.nil? || v.to_s.strip.empty? }
          yield record
        end
      else
        workbook = Xsv.open(session[:path], parse_headers: true)
        worksheet = workbook.first
        worksheet.each do |row|
          record = process_row(row, mappings)
          next if record.empty? || record.values.all? { |v| v.nil? || v.to_s.strip.empty? }
          yield record
        end
      end
    end

    def process_row(row, mappings)
      record = {}
      row.each do |row_header, value|
        attribute = mappings.permit!.to_h.find { |column_name, attribute_name| column_name == row_header }
        next if attribute.nil?
        attribute = attribute[1]
        next if attribute.nil? || attribute == ""
        record[attribute.to_sym] = value
      end
      record
    end

    def rails_routes
      ::Rails.application.routes.url_helpers
    end
  end
end
