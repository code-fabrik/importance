module Importance
  class ApplicationController < ::ApplicationController
    include Rails.application.routes.url_helpers
    helper Rails.application.routes.url_helpers
  end
end
