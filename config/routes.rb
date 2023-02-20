Rails.application.routes.draw do
  resources :configs
  resources :servers, only: :update
  resources :hetzner_servers, only: %i[index edit update] do
    collection do
      post :sync
    end

    member do
      post :bootstrap
    end
  end

  get "config", to: "configs#show", as: "get_config"

  root "servers#index"
end
