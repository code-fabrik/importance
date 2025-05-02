require "xsv"

module Importance
  class FileService
    attr_reader :upload, :importer

    def initialize(importer, upload)
      @importer = Importance.configuration.importers[importer.to_sym]

      raise ArgumentError, "Importer not found: #{importer}" if @importer.nil?

      @upload = upload
    end

    def store
      raise ArgumentError, "Upload cannot be nil" if upload.nil?

      system_tmp_dir = Dir.tmpdir
      upload_path = upload.tempfile.path
      upload_extension = File.extname(upload.original_filename)
      persist_filename = "#{SecureRandom.uuid}#{upload_extension}"

      persist_path =  File.join(system_tmp_dir, persist_filename)

      raise ArgumentError, "File does not exist at #{upload_path}" if !File.exist?(upload_path)

      FileUtils.mv(upload_path, persist_path)

      persist_path
    end

    def headers
      worksheet.first.keys.map do |cell|
        Header.new(cell, importer.attributes)
      end
    end

    def samples
      worksheet.first(5)
    end

    def import(mappings)
      raise ArgumentError, "Mapping cannot be nil" if mappings.nil?

      workbook = Xsv.open(upload, parse_headers: true)
      worksheet = workbook.first

      records_to_import = []

      worksheet.each_with_index do |row, index|
        record = {}
        row.each do |row_header, value|
          # "Vorname" => "Hans" must be mapped to :first_name
          attribute = mappings.permit!.to_h.find { |column_name, attribute_name| column_name == row_header }
          next if attribute.nil?
          attribute = attribute[1]
          next if attribute == ""
          record[attribute.to_sym] = value
        end
        records_to_import << record

        if importer.batch && records_to_import.size >= importer.batch
          importer.callback.call(records_to_import)
          records_to_import = []
        end
      end

      if records_to_import.any?
        importer.callback.call(records_to_import)
      end
    end

    private

    def workbook
      @workbook ||= Xsv.open(upload.tempfile.path, parse_headers: true)
    end

    def worksheet
      @worksheet ||= workbook.first
    end

    # This maps import headers to their attribute candidates
    class Header
      attr_reader :name, :attributes

      def initialize(name, attributes)
        @name = name
        @attributes = attributes
      end

      def candidates
        # Compare header name and attribute header and find best match
        attribute_with_similiarity = attributes.map do |attribute|
          distances = attribute.labels.map do |label|
            DidYouMean::Levenshtein.distance(name, label)
          end
          distance = distances.min
          percentage = distance / name.length.to_f
          similarity = 1 - percentage
          [ attribute, similarity ]
        end
        dummy_entry = [ OpenStruct.new(key: nil, labels: [ "Ignorieren" ]), 0.6 ]
        (attribute_with_similiarity + [ dummy_entry ]).sort_by { |_, similarity| similarity }.reverse.map { |attribute, _| attribute }
      end
    end
  end
end
