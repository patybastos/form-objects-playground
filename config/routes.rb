Rails.application.routes.draw do
  resource :signup, only: %i[new create]

  get "up" => "rails/health#show", as: :rails_health_check

  root "home#show"
end
