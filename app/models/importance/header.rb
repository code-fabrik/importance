module Importance
  class Header
    attr_reader :attribute, :file_headers

    def initialize(attribute, file_headers)
      @attribute = attribute
      @file_headers = file_headers
    end

    def candidates
      # Compare attribute labels with file headers and find best matches
      header_with_similarity = file_headers.map do |header|
        distances = attribute.labels.map do |label|
          DidYouMean::Levenshtein.distance(header, label)
        end
        distance = distances.min
        percentage = distance / header.length.to_f
        similarity = 1 - percentage
        [ header, similarity ]
      end
      dummy_entry = [ I18n.t("importance.ignore"), 0.6 ]
      (header_with_similarity + [ dummy_entry ]).sort_by { |_, similarity| similarity }.reverse.map { |header, _| header }
    end
  end
end
