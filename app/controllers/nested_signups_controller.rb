class NestedSignupsController < ApplicationController
  def new
    @account = NestedSignup::Account.new
    @account.users.build
  end

  def create
    @account = NestedSignup::Account.new(account_params)

    if @account.save
      user = @account.users.first
      session[:user_id] = user.id
      redirect_to root_path, notice: "Welcome, #{user.name}!"
    else
      @account.users.build if @account.users.empty?
      render :new, status: :unprocessable_content
    end
  end

  private

  def account_params
    params.require(:nested_signup_account).permit(
      :name, users_attributes: %i[name email password password_confirmation terms_of_service]
    )
  end
end
