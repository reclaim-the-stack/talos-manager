Rails.application.routes.draw do
  resources :configs
  resources :servers, only: :update
  resources :hetzner_servers, only: %i[index edit update]

  get "config", to: "configs#show", as: "get_config"

  root "servers#index"
end
