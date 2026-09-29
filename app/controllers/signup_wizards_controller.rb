class SignupWizardsController < ApplicationController
  SESSION_KEY = :signup_wizard

  before_action :build_wizard
  before_action :redirect_to_incomplete_step

  def show
  end

  def update
    if !@wizard.update(wizard_params)
      render :show, status: :unprocessable_content
    elsif @wizard.completed?
      session.delete(SESSION_KEY)
      session[:user_id] = @wizard.user.id
      redirect_to root_path, notice: "Welcome, #{@wizard.user.name}!"
    else
      session[SESSION_KEY] = @wizard.to_session
      redirect_to signup_wizard_path(@wizard.next_step)
    end
  end

  private

  def build_wizard
    @wizard = SignupWizard.new(params[:step], session[SESSION_KEY] || {})
  end

  def redirect_to_incomplete_step
    if (step = @wizard.first_incomplete_step)
      redirect_to signup_wizard_path(step)
    end
  end

  def wizard_params
    params.require(:signup).permit(*SignupWizard::STEPS.fetch(@wizard.step))
  end
end
