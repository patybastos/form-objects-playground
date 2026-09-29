# Creates an Account and its first User in a single transaction.
#
# The rules here only make sense *during signup* — they aren't properties
# of a User, so they stay out of the model:
#   - the user must accept the terms of service
#   - password must be confirmed and meet the signup strength policy
#   - one form spans two models (Account + User)
class SignupForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  EMAIL_FORMAT = URI::MailTo::EMAIL_REGEXP
  PASSWORD_MIN_LENGTH = 8

  attribute :account_name, :string
  attribute :name, :string
  attribute :email, :string
  attribute :password, :string
  attribute :password_confirmation, :string
  attribute :terms_of_service, :boolean

  validates :account_name, :name, :email, :password, presence: true
  validates :email, format: { with: EMAIL_FORMAT }, allow_blank: true
  validates :password, length: { minimum: PASSWORD_MIN_LENGTH }, confirmation: true, allow_blank: true
  # Both validators skip nil by default, so a client that simply omits the
  # field (curl, API) would bypass them. Browsers never hit this: check_box
  # always sends a hidden "0".
  validates :password_confirmation, presence: true, if: -> { password.present? }
  validates :terms_of_service, acceptance: { accept: true, allow_nil: false }

  attr_reader :user

  # Params are nested under :signup, not :signup_form.
  def self.model_name
    ActiveModel::Name.new(self, nil, "Signup")
  end

  def save
    return false unless valid?

    ActiveRecord::Base.transaction do
      account = Account.create!(name: account_name)
      @user = account.users.create!(name: name, email: email, password: password)
    end

    true
  rescue ActiveRecord::RecordInvalid => e
    # Model invariants (e.g. email uniqueness) can still fail after the
    # form's own validations pass. Surface them on the form.
    promote_errors(e.record)
    false
  end

  private

  def promote_errors(record)
    record.errors.each do |error|
      attr = record.is_a?(Account) && error.attribute == :name ? :account_name : error.attribute
      errors.add(respond_to?(attr) ? attr : :base, error.message)
    end
  end
end
