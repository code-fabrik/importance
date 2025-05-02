Rails.application.routes.draw do
  mount Importance::Engine => "/importance"

  resources :students, only: [:index]
end
