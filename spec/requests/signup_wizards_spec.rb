require "rails_helper"

RSpec.describe "Signup wizard", type: :request do
  def submit(step, fields)
    patch signup_wizard_path(step), params: { signup: fields }
  end

  it "walks through every step and signs the user in" do
    get signup_wizard_path("account")
    expect(response.body).to include("Step 1 of 3")

    submit("account", account_name: "Acme")
    expect(response).to redirect_to(signup_wizard_path("profile"))

    submit("profile", name: "Ada Lovelace", email: "ada@example.com")
    expect(response).to redirect_to(signup_wizard_path("credentials"))

    follow_redirect!
    expect(response.body).to include("ada@example.com")

    expect {
      submit("credentials", password: "s3cret-pass", password_confirmation: "s3cret-pass", terms_of_service: "1")
    }.to change(User, :count).by(1)

    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(response.body).to include("Welcome, Ada Lovelace!")
  end

  it "re-renders the step with 422 when it's invalid" do
    submit("account", account_name: "")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Account name can&#39;t be blank")
  end

  it "redirects to the first incomplete step when skipping ahead" do
    submit("account", account_name: "Acme")
    get signup_wizard_path("credentials")

    expect(response).to redirect_to(signup_wizard_path("profile"))
  end

  it "404s on unknown steps" do
    get "/wizard/nope"

    expect(response).to have_http_status(:not_found)
  end
end
