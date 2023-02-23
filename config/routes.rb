Rails.application.routes.draw do
  resources :configs
  resources :clusters do
    member do
      get :talosconfig
      get :kubeconfig
    end
  end
  resources :machine_configs, only: %i[show new create destroy]
  resources :hetzner_servers, only: %i[index edit update] do
    collection do
      post :sync
    end

    member do
      post :bootstrap
      post :rescue
    end
  end

  get "config", to: "configs#show", as: "get_config"

  root "hetzner_servers#index"
end
