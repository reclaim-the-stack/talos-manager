Rails.application.routes.draw do
  scope "admin" do
    resources :api_keys, only: %i[new create edit update destroy]
    resources :configs
    resources :clusters do
      member do
        get :talosconfig
        get :kubeconfig
      end
    end
    resources :machine_configs, only: %i[show new create destroy]
    resources :servers, only: %i[index edit update] do
      collection do
        post :sync
      end

      member do
        post :bootstrap
        post :rescue
        post :reset
      end
    end
    resource :settings, only: %i[show]
    resources :talos_image_factory_settings, only: %i[update]
  end

  get "config", to: "configs#show", as: "get_config"

  root to: redirect("/admin/servers")
end
