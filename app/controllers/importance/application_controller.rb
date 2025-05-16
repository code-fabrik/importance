module Importance
  class ApplicationController < ::ApplicationController
    include Rails.application.routes.url_helpers
    helper Rails.application.routes.url_helpers

    def default_url_options
      { script_name: Rails.application.config.relative_url_root || "" }
    end
  end
end
