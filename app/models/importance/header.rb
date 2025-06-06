module Importance
  class Header
    def self.match_attributes_to_headers(importer_attributes, file_headers)
      attribute_mappings = {}

      importer_attributes.each do |attribute|
        best_header = nil
        best_similarity = 0

        file_headers.each do |header|
          attribute.labels.each do |label|
            if header == label
              best_header = header
              best_similarity = 1.0
              break # No need to check further if an exact match is found
            end
            distance = DidYouMean::Levenshtein.distance(header, label)
            percentage = distance / header.length.to_f
            similarity = 1 - percentage
            if similarity > best_similarity
              best_similarity = similarity
              best_header = header
            end
          end
        end

        # Only assign if similarity is reasonable (> 0.5) and header isn't already taken
        if best_similarity > 0.5 && !attribute_mappings.values.include?(best_header)
          attribute_mappings[attribute.key] = best_header
        end
      end

      attribute_mappings
    end

    def self.default_value_for_header(file_header, attribute_mappings)
      attribute_mappings.key(file_header) || ""
    end
  end
end
