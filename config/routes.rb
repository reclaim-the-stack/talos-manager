Rails.application.routes.draw do
  resources :configs
  resources :servers, only: :update

  get "config", to: "configs#show", as: "get_config"

  root "servers#index"
end
