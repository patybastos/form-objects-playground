Rails.application.routes.draw do
  resource :signup, only: %i[new create]

  scope "wizard", constraints: { step: Regexp.union(SignupWizard.steps) } do
    get ":step", to: "signup_wizards#show", as: :signup_wizard
    patch ":step", to: "signup_wizards#update"
  end
  get "wizard", to: redirect("/wizard/#{SignupWizard.steps.first}")

  get "up" => "rails/health#show", as: :rails_health_check

  root "home#show"
end
