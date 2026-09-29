require "rails_helper"

# Each example documents a trade-off of putting signup on the models with
# accepts_nested_attributes_for, compared to SignupForm.
RSpec.describe NestedSignup::Account, type: :model do
  let(:user_attributes) do
    {
      name: "Ada Lovelace",
      email: "ada@example.com",
      password: "s3cret-pass",
      password_confirmation: "s3cret-pass",
      terms_of_service: "1"
    }
  end

  def build_signup(users: [ user_attributes ])
    described_class.new(name: "Acme", users_attributes: users)
  end

  it "creates the account and its first user in one save" do
    expect { build_signup.save! }.to change(Account, :count).by(1).and change(User, :count).by(1)
  end

  it "keys errors on the nested association, not on the field the user sees" do
    build_signup.save!
    duplicate = build_signup

    expect(duplicate.save).to be(false)
    expect(duplicate.errors.attribute_names).to include(:"users.email")
    expect(duplicate.errors.full_messages).to include("Users email has already been taken")
  end

  it "needs an explicit limit, or a client can create many users in one signup" do
    second = user_attributes.merge(email: "grace@example.com")

    expect { build_signup(users: [ user_attributes, second ]) }
      .to raise_error(ActiveRecord::NestedAttributes::TooManyRecords)
  end

  describe "rules leaking out of signup" do
    it "can't create an Account without a user anymore (seeds, admin tools)" do
      expect(described_class.new(name: "Seeded")).not_to be_valid
    end

    it "can't add a user to an existing account without faking signup-only fields" do
      account = build_signup.tap(&:save!)
      invited = account.users.build(name: "Grace", email: "grace@example.com", password: "s3cret-pass")

      expect(invited).not_to be_valid
      expect(invited.errors.attribute_names).to include(:terms_of_service, :password_confirmation)
    end

    it "runs the 'signup' callback on every Account creation" do
      allow(Rails.logger).to receive(:info)

      build_signup.save!

      expect(Rails.logger).to have_received(:info).with(/\[signup\]/)
    end
  end
end
