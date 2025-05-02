module Importance
  class ImportsController < ApplicationController
    def map
      fs = FileService.new(params[:importer], params[:file])

      @headers = fs.headers
      @samples = fs.samples

      @path = fs.store

      session[:redirect_url] = request.referrer
    end

    def import
      fs = FileService.new(params[:importer], params[:file])

      fs.import(params[:mappings])

      redirect_to session[:redirect_url] || root_path, notice: "Import completed."
    end
  end
end
