module NestedSignup
  class User < ApplicationRecord
    self.table_name = "users"

    belongs_to :account, class_name: "NestedSignup::Account", inverse_of: :users

    has_secure_password validations: false

    normalizes :email, with: ->(email) { email.strip.downcase }

    # Virtual attribute that only exists for signup, now part of every User.
    attr_accessor :terms_of_service

    validates :name, presence: true
    validates :email, presence: true, uniqueness: true
    validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
    validates :password, presence: true, length: { minimum: 8 }, confirmation: true
    validates :password_confirmation, presence: true
    # Signup-only rules: any other path that creates a user (admin invite,
    # seeds, console) now has to fake terms acceptance or grow an
    # `if: :signing_up?` flag.
    validates :terms_of_service, acceptance: { allow_nil: false }
  end
end
