module Importance
  class BootstrapLayout < BlankLayout
    def self.select_class
      "form-select"
    end

    def self.submit_class
      "btn btn-primary"
    end

    def self.table_class
      "table"
    end

    def self.wrapper_class
      "table-responsive"
    end
  end
end
