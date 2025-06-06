module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate
  end

  private
    def authenticate
      Current.user = OpenStruct.new(email: "test@example.com")
    end
end
