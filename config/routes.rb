Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"

  root "home#index"
  resource :session, only: %i[new create destroy]

  # ADMIN-gated site-wide usage dashboard (ARCHITECTURE.md §8). The whole namespace
  # is gated behind the ADMIN role by Admin::BaseController (404 for non-admins).
  namespace :admin do
    resource :stats, only: [ :show ]
  end

  # Two dynamic routes for every calculator — the slug resolves to a `Calculators::X`
  # class by auto-discovery. Adding a calculator never edits this file (ARCHITECTURE.md §3).
  # GET renders the calculator page; POST runs it (JSON envelope §4 or a Turbo Stream).
  get  "/calculators/:slug", to: "calculators#show"
  post "/calculators/:slug", to: "calculators#create"
end
