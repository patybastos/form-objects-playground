require "rails_helper"

RSpec.describe "Nested signups", type: :request do
  let(:params) do
    {
      nested_signup_account: {
        name: "Acme",
        users_attributes: {
          "0" => {
            name: "Ada Lovelace",
            email: "ada@example.com",
            password: "s3cret-pass",
            password_confirmation: "s3cret-pass",
            terms_of_service: "1"
          }
        }
      }
    }
  end

  it "renders the form" do
    get new_nested_signup_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("nested_signup_account[users_attributes][0][email]")
  end

  it "creates the account and user, signs in and redirects home" do
    expect { post nested_signup_path, params: params }.to change(User, :count).by(1)

    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(response.body).to include("Welcome, Ada Lovelace!")
  end

  it "re-renders the form with 422 when invalid" do
    params[:nested_signup_account][:users_attributes]["0"][:terms_of_service] = "0"

    expect { post nested_signup_path, params: params }.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Users terms of service must be accepted")
  end
end
