Rails.application.routes.draw do
  resource :session, only: [ :new, :create, :destroy ]
  resource :registration, only: [ :new, :create ]

  resources :passwords, param: :token

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up", to: "rails/health#show", as: :rails_health_check
  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get "manifest", to: "rails/pwa#manifest", as: :pwa_manifest
  get "service_worker", to: "rails/pwa#service_worker", as: :pwa_service_worker

  namespace :admin do
    mount MissionControl::Jobs::Engine, at: "/jobs"
  end

  scope "o-:org_slug" do
    get "home", to: "home#index", as: :home
  end

  # Defines the root path route ("/")
  root "marketing#index"
end
