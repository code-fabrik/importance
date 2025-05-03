Importance::Engine.routes.draw do
  post "/submit", to: "imports#submit", as: :submit
  get "/map", to: "imports#map", as: :map
  post "/import", to: "imports#import", as: :import
end
