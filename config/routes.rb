Importance::Engine.routes.draw do
  post "/map", to: "imports#map", as: :map
  post "/import", to: "imports#import", as: :import
end
