require "rails_helper"

RSpec.describe SignupForm, type: :model do
  let(:valid_attributes) do
    {
      account_name: "Acme",
      name: "Ada Lovelace",
      email: "ada@example.com",
      password: "s3cret-pass",
      password_confirmation: "s3cret-pass",
      terms_of_service: "1"
    }
  end

  subject(:form) { described_class.new(valid_attributes) }

  describe "validations" do
    it { is_expected.to be_valid }

    it { is_expected.to validate_presence_of(:account_name) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_presence_of(:password) }
    it { is_expected.to validate_length_of(:password).is_at_least(8) }
    it { is_expected.to validate_confirmation_of(:password) }

    it "requires the terms of service to be accepted" do
      form.terms_of_service = "0"

      expect(form).not_to be_valid
      expect(form.errors[:terms_of_service]).to include("must be accepted")
    end

    it "requires terms_of_service even when the field is omitted entirely" do
      form.terms_of_service = nil

      expect(form).not_to be_valid
      expect(form.errors[:terms_of_service]).to include("must be accepted")
    end

    it "requires password_confirmation even when the field is omitted entirely" do
      form.password_confirmation = nil

      expect(form).not_to be_valid
      expect(form.errors[:password_confirmation]).to include("can't be blank")
    end

    it "rejects malformed emails" do
      form.email = "not-an-email"

      expect(form).not_to be_valid
      expect(form.errors[:email]).to include("is invalid")
    end

    it "casts terms_of_service to a boolean" do
      expect(form.terms_of_service).to be(true)
    end
  end

  describe "#save" do
    it "creates the account and its first user" do
      expect { form.save }.to change(Account, :count).by(1).and change(User, :count).by(1)

      expect(form.user).to have_attributes(name: "Ada Lovelace", email: "ada@example.com")
      expect(form.user.account.name).to eq("Acme")
      expect(form.user.authenticate("s3cret-pass")).to eq(form.user)
    end

    it "returns false and persists nothing when invalid" do
      form.terms_of_service = "0"

      expect { expect(form.save).to be(false) }.not_to change(Account, :count)
    end

    context "when the email is already taken" do
      before do
        account = Account.create!(name: "Other")
        account.users.create!(name: "Someone", email: "ADA@example.com", password: "whatever1")
      end

      it "rolls back the account and surfaces the model error on the form" do
        expect { expect(form.save).to be(false) }.not_to change(Account, :count)

        expect(form.errors[:email]).to include("has already been taken")
      end
    end
  end

  describe "the User model without the form" do
    # The point of the form object: flow-specific rules don't leak into the
    # model, so other creation paths (seeds, admin invite) aren't forced
    # through signup rules like terms acceptance or password confirmation.
    it "can be created without terms or confirmation" do
      account = Account.create!(name: "Seeded")

      expect(account.users.create(name: "Seed", email: "seed@example.com", password: "x")).to be_persisted
    end
  end
end
