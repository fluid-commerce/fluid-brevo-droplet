Rails.application.routes.draw do
  root "home#index"

  devise_for :users

  post "webhook", to: "webhooks#create", as: :webhook
  post "brevo/webhook", to: "brevo_webhooks#receive", as: :brevo_webhook
  
  # Brevo configuration (public access)
  get "brevo", to: "brevo_configuration#show", as: :brevo_configuration
  patch "brevo", to: "brevo_configuration#update"
  post "brevo/verify_connection", to: "brevo_configuration#verify_connection", as: :brevo_verify_connection
  post "brevo/verify_email", to: "brevo_configuration#verify_email", as: :brevo_verify_email
  post "brevo/manual_sync", to: "brevo_configuration#manual_sync", as: :brevo_manual_sync
  post "brevo/sync_lists", to: "brevo_configuration#sync_lists", as: :brevo_sync_lists
  patch "brevo/update_default_list", to: "brevo_configuration#update_default_list", as: :brevo_update_default_list

  namespace :admin do
    get "dashboard/index"
    resource :droplet, only: %i[ create update ]
    resources :settings, only: %i[ index edit update ]
    resources :users
    resources :callbacks, only: %i[ index show edit update ] do
      post :sync, on: :collection
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
