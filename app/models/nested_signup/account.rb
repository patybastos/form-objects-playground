# Counterpoint to SignupForm: the same signup done the "fat model" way,
# with accepts_nested_attributes_for and the signup rules on the models.
#
# Namespaced and pointed at the same tables so it can live next to the
# form-object version without leaking into Account/User. The specs in
# spec/models/nested_signup show what this design costs.
module NestedSignup
  class Account < ApplicationRecord
    self.table_name = "accounts"

    has_many :users, class_name: "NestedSignup::User", inverse_of: :account, dependent: :destroy

    # Without limit, a client can post users_attributes with any number of
    # entries and create that many users in one signup.
    accepts_nested_attributes_for :users, limit: 1

    validates :name, presence: true
    # Signup needs a first user, but now *every* Account creation does.
    validates :users, presence: true, on: :create

    # Reads as "on signup", but fires on every Account creation (seeds,
    # admin tools, tests). In SignupForm, a side effect like this is an
    # explicit line in #save.
    after_create_commit :log_signup

    private

    def log_signup
      Rails.logger.info("[signup] account=#{id} name=#{name.inspect}")
    end
  end
end
