class SignupsController < ApplicationController
  def new
    @signup = SignupForm.new
  end

  def create
    @signup = SignupForm.new(signup_params)

    if @signup.save
      session[:user_id] = @signup.user.id
      redirect_to root_path, notice: "Welcome, #{@signup.user.name}!"
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def signup_params
    params.require(:signup).permit(
      :account_name, :name, :email, :password, :password_confirmation, :terms_of_service
    )
  end
end
