module Importance
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
      dummy_entry = [ OpenStruct.new(key: nil, labels: [ I18n.t("ignore") ]), 0.6 ]
      (attribute_with_similiarity + [ dummy_entry ]).sort_by { |_, similarity| similarity }.reverse.map { |attribute, _| attribute }
    end
  end
end
