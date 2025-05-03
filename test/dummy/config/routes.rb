Rails.application.routes.draw do
  
  root to: "students#index"
  
  resources :students, only: [:index]
  
  mount Importance::Engine => "/importance"
end
