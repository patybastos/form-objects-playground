# Only invariants that must hold no matter how a user is created (signup,
# admin invite, seeds, console) live here. Rules that belong to a specific
# flow — terms acceptance, password confirmation — live in the form object.
class User < ApplicationRecord
  belongs_to :account

  has_secure_password validations: false

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
end
