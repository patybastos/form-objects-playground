require "rails_helper"

RSpec.describe "Signups", type: :request do
  let(:params) do
    {
      signup: {
        account_name: "Acme",
        name: "Ada Lovelace",
        email: "ada@example.com",
        password: "s3cret-pass",
        password_confirmation: "s3cret-pass",
        terms_of_service: "1"
      }
    }
  end

  describe "GET /signup/new" do
    it "renders the form" do
      get new_signup_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Create your account")
    end
  end

  describe "POST /signup" do
    it "creates the account and user, signs in and redirects home" do
      expect { post signup_path, params: params }.to change(User, :count).by(1)

      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include("Welcome, Ada Lovelace!")
      expect(response.body).to include("Signed in as <strong>Ada Lovelace</strong>")
    end

    it "re-renders the form with 422 when invalid" do
      params[:signup][:terms_of_service] = "0"

      expect { post signup_path, params: params }.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Terms of service must be accepted")
    end
  end
end
