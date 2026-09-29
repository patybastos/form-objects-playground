require "rails_helper"

RSpec.describe SignupWizard do
  let(:stored) { { "account_name" => "Acme", "name" => "Ada Lovelace", "email" => "ada@example.com" } }
  let(:credentials) do
    ActionController::Parameters.new(
      password: "s3cret-pass", password_confirmation: "s3cret-pass", terms_of_service: "1"
    ).permit!
  end

  describe "#update" do
    it "only validates the fields of the current step" do
      wizard = described_class.new("account")

      expect(wizard.update(ActionController::Parameters.new(account_name: "Acme").permit!)).to be(true)
      expect(wizard.errors).to be_empty
      expect(wizard).not_to be_completed
    end

    it "reports errors for the current step's fields only" do
      wizard = described_class.new("profile", "account_name" => "Acme")

      expect(wizard.update(ActionController::Parameters.new(name: "", email: "nope").permit!)).to be(false)
      expect(wizard.errors.attribute_names).to contain_exactly(:name, :email)
    end

    it "ignores fields that belong to other steps" do
      wizard = described_class.new("account")
      wizard.update(ActionController::Parameters.new(account_name: "Acme", email: "sneaky@example.com").permit!)

      expect(wizard.email).to be_nil
    end

    it "creates the account and user on the last step" do
      wizard = described_class.new("credentials", stored)

      expect { expect(wizard.update(credentials)).to be(true) }.to change(User, :count).by(1)
      expect(wizard).to be_completed
      expect(wizard.user.account.name).to eq("Acme")
    end

    it "sends the user back to the step that owns a write-time error" do
      Account.create!(name: "Other").users.create!(name: "Someone", email: "ada@example.com", password: "whatever1")
      wizard = described_class.new("credentials", stored)

      expect(wizard.update(credentials)).to be(false)
      expect(wizard.step).to eq("profile")
      expect(wizard.errors[:email]).to include("has already been taken")
    end
  end

  describe "#to_session" do
    it "never includes the password" do
      wizard = described_class.new("credentials", stored)
      wizard.signup.password = "s3cret-pass"

      expect(wizard.to_session.keys).to contain_exactly("account_name", "name", "email")
    end
  end

  describe "#first_incomplete_step" do
    it "is nil when every earlier step is valid" do
      expect(described_class.new("credentials", stored).first_incomplete_step).to be_nil
    end

    it "points at the earliest step missing data" do
      expect(described_class.new("credentials", "account_name" => "Acme").first_incomplete_step).to eq("profile")
      expect(described_class.new("credentials").first_incomplete_step).to eq("account")
    end
  end
end
