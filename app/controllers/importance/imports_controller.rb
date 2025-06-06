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
      session[:additional_data] = params[:additional_data].present? ? params[:additional_data].to_json : {}.to_json

      redirect_to map_path
    end

    # Mapping page. Load headers and samples, display the form.
    def map
      importer = Importance.configuration.importers[session[:importer].to_sym]

      raise ArgumentError, "Importer cannot be nil" if importer.nil?

      workbook = Xsv.open(session[:path], parse_headers: true)
      worksheet = workbook.first

      @headers = worksheet.first.keys.map do |cell|
        Importance::Header.new(cell, importer.attributes)
      end
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

      additional_data = session[:additional_data].present? ? JSON.parse(session[:additional_data], symbolize_names: true) : {}
      context = ImportContext.new(self, additional_data)

      context.instance_exec(&importer.setup_callback) if importer.setup_callback

      begin
        records_to_import = []

        worksheet.each_with_index do |row, index|
          record = {}
          row.each do |row_header, value|
            attribute = mappings.permit!.to_h.find { |column_name, attribute_name| column_name == row_header }
            next if attribute.nil?
            attribute = attribute[1]
            next if attribute == ""
            record[attribute.to_sym] = value
          end
          records_to_import << record

          if importer.batch && records_to_import.size >= importer.batch
            # Run callback in context
            context.instance_exec(records_to_import, &importer.perform_callback)
            records_to_import = []
          end
        end

        if records_to_import.any?
          context.instance_exec(records_to_import, &importer.perform_callback)
        end

        # Run teardown if defined
        context.instance_exec(&importer.teardown_callback) if importer.teardown_callback

        # Run after import callback
        if importer.after_import_callback
          instance_exec(&importer.after_import_callback)
        else
          redirect_to session[:redirect_url] || root_path, notice: "Import completed."
        end
      rescue => e
        # Ensure teardown is called even if an error occurs
        context.instance_exec(&importer.teardown_callback) if importer.teardown_callback
        raise e
      end
    end

    private

    def rails_routes
      ::Rails.application.routes.url_helpers
    end
  end
end
