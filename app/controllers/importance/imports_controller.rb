require "roo"
require "csv"

module Importance
  class ImportsController < ApplicationController
    # Form submission target. Persist the file and redirect to the mapping page.
    def submit
      upload = params[:file]
      session[:redirect_url] = params[:redirect_url]
      session[:importer] = params[:importer].to_sym

      if upload.nil?
        flash[:alert] = t("importance.errors.no_file")
        redirect_to session[:redirect_url] and return
      end

      upload_extension = File.extname(upload.original_filename).downcase
      supported_extensions = [ ".xlsx", ".xls", ".csv" ]

      if !supported_extensions.include?(upload_extension)
        flash[:alert] = t("importance.errors.invalid_file_type", types: supported_extensions.join(", "))
        redirect_to session[:redirect_url] and return
      end

      system_tmp_dir = Dir.tmpdir
      upload_path = upload.tempfile.path
      persist_filename = "#{SecureRandom.uuid}#{upload_extension}"

      persist_path =  File.join(system_tmp_dir, persist_filename)
      session[:path] = persist_path

      if !File.exist?(upload_path)
        flash[:alert] = t("importance.errors.no_file")
        redirect_to session[:redirect_url] and return
      end

      FileUtils.mv(upload_path, persist_path)

      redirect_to map_path
    end

    # Mapping page. Load headers and samples, display the form.
    def map
      @layout = "Importance::#{Importance.configuration.layout.to_s.camelize}Layout".constantize
      @importer = Importance.configuration.importers[session[:importer].to_sym]

      if @importer.nil?
        flash[:alert] = t("importance.errors.no_importer")
        redirect_to session[:redirect_url] and return
      end

      @importer.add_spreadsheet(session[:path])
    end

    # Import page. Load the file according to the mapping and import it.
    # Mappings param is of the form mappings[excel_column_idx] = target_attribute
    # mappings[0] = "first_name", mappings[1] = "", mappings[2] = "last_name" ...
    def import
      @layout = "Importance::#{Importance.configuration.layout.to_s.camelize}Layout".constantize
      @importer = Importance.configuration.importers[session[:importer].to_sym]
      @importer.add_spreadsheet(session[:path])

      if @importer.nil?
        flash[:alert] = t("importance.errors.no_importer")
        render :map, status: :unprocessable_entity and return
      end

      if params[:mappings].nil?
        flash[:alert] = t("importance.errors.no_mappings")
        render :map, status: :unprocessable_entity and return
      end

      @mappings = params[:mappings].permit!.to_h.map { |k, v| [ k.to_i, v ] }.to_h

      @importer.importer_attributes.each do |attribute|
        next if !attribute.options[:required]
        next if @mappings.values.include?(attribute.key.to_s)

        flash[:alert] = t("importance.errors.missing_mapping", attribute: attribute.labels.first)
        render :map, status: :unprocessable_entity and return
      end

      @mappings.each do |column_index, attribute_name|
        next if attribute_name == ""
        next if @mappings.values.count(attribute_name) <= 1

        attribute_label = @importer.importer_attributes.find { |attr| attr.key.to_s == attribute_name }.labels.first
        flash[:alert] = t("importance.errors.duplicate_mapping", attribute: attribute_label)
        render :map, status: :unprocessable_entity and return
      end

      if @importer.setup_callback
        instance_exec(&@importer.setup_callback)
      end

      records_to_import = []

      @importer.each_processed_row(session[:path], @mappings) do |record|
        records_to_import << record

        if @importer.batch && records_to_import.size >= @importer.batch
          instance_exec(records_to_import, &@importer.perform_callback)
          records_to_import = []
        end
      end

      if records_to_import.any?
        instance_exec(records_to_import, &@importer.perform_callback)
      end

      if @importer.teardown_callback
        instance_exec(&@importer.teardown_callback)
      else
        redirect_to (session[:redirect_url] || main_app.root_path), notice: t("importance.success.import_completed")
      end
    end
  end
end
