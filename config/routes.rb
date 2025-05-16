Importance::Engine.routes.draw do
  post "/importance/submit", to: "imports#submit", as: :submit
  get "/importance/map", to: "imports#map", as: :map
  post "/importance/import", to: "imports#import", as: :import
end
