module Importance
  class ImportContext
    attr_reader :controller

    def initialize(controller, additional_data = {})
      @controller = controller
      @vars = {}
      @vars[:additional_data] = additional_data if additional_data.present?
    end

    # Allow access to controller methods like current_user, params, etc.
    def method_missing(method, *args, &block)
      if method.to_s.end_with?("=")
        variable_name = method.to_s.chop.to_sym
        @vars[variable_name] = args.first
      elsif @vars.key?(method)
        @vars[method]
      elsif controller.respond_to?(method, true)
        controller.send(method, *args, &block)
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      method.to_s.end_with?("=") ||
        @vars.key?(method) ||
        controller.respond_to?(method, include_private) ||
        super
    end
  end
end
