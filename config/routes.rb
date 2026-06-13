Rails.application.routes.draw do
  namespace :admin do
    resource :survey_operation, only: :show do
      post :create_current_week_survey
      post :notify_unanswered_users
    end

    resources :surveys, only: [] do
      resource :results, only: :show, controller: "survey_results", defaults: { format: :csv }
    end
  end

  mount RailsAdmin::Engine => "/admin", as: "rails_admin"

  root "home#index"
  get "/login", to: "home#index", as: :login

  post "/auth/google_oauth2", to: "sessions#missing_google_configuration"
  post "/auth/development", to: "sessions#development_login", as: :development_login
  post "/auth/:provider/callback", to: "sessions#create"
  get "/auth/:provider/callback", to: "sessions#create"
  get "/auth/failure", to: "sessions#failure"
  delete "/logout", to: "sessions#destroy"

  resources :survey_assignments, only: [] do
    resource :response, only: %i[new create], controller: "survey_responses"
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
