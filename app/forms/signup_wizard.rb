# Splits signup across several requests, one step per page.
#
# Doesn't redefine any rule: every step runs SignupForm's validations and
# only looks at the errors for its own fields, so the single-page signup
# and the wizard can never disagree about what a valid signup is.
#
# Answers from finished steps are kept in the session between requests.
# The password is asked for on the last step, so it's never stored there.
class SignupWizard
  include ActiveModel::Model

  STEPS = {
    "account" => %i[account_name],
    "profile" => %i[name email],
    "credentials" => %i[password password_confirmation terms_of_service]
  }.freeze

  SESSION_ATTRIBUTES = (STEPS["account"] + STEPS["profile"]).map(&:to_s).freeze

  attr_reader :step, :signup

  delegate(*SignupForm.attribute_names.map(&:to_sym), :user, to: :signup)

  def self.model_name
    ActiveModel::Name.new(self, nil, "Signup")
  end

  def self.steps
    STEPS.keys
  end

  def initialize(step, stored = {})
    @step = step
    @signup = SignupForm.new(stored.to_h.slice(*SESSION_ATTRIBUTES))
  end

  # Assigns this step's fields and validates them. On the last step it also
  # saves the signup. Returns false if the step (or the save) failed.
  def update(params)
    signup.assign_attributes(params.to_h.slice(*STEPS.fetch(step).map(&:to_s)))
    return false unless validate_step

    last_step? ? save_signup : true
  end

  def completed?
    user.present?
  end

  # The first earlier step that isn't valid with what's stored, if any.
  # Used to stop someone from jumping straight to a later step's URL.
  def first_incomplete_step
    previous_steps.find { |s| step_errors(s).any? }
  end

  def to_session
    signup.attributes.slice(*SESSION_ATTRIBUTES)
  end

  def step_number
    self.class.steps.index(step) + 1
  end

  def next_step
    self.class.steps[step_number]
  end

  def previous_step
    previous_steps.last
  end

  def last_step?
    next_step.nil?
  end

  private

  def previous_steps
    self.class.steps.take(step_number - 1)
  end

  def validate_step
    errors.clear
    step_errors(step).each { |error| errors.import(error) }
    errors.empty?
  end

  def step_errors(step)
    signup.validate
    signup.errors.select { |error| STEPS.fetch(step).include?(error.attribute) }
  end

  # Some errors only appear on write (e.g. a taken email). Send the user
  # back to the step that owns the field so they can fix it there.
  def save_signup
    return true if signup.save

    @step = self.class.steps.find { |s| signup.errors.any? { |e| STEPS[s].include?(e.attribute) } } || step
    errors.clear
    signup.errors.each { |error| errors.import(error) }
    false
  end
end
