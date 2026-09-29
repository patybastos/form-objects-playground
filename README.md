# form-objects-playground

A hands-on Rails lab about **Form Objects**: where the rules of a flow like signup should
live, and why "on the model" is usually the wrong answer. The same signup is built
three ways: a single-page form object, a multi-step wizard, and the
`accepts_nested_attributes_for` + callbacks approach as a counterpoint. The specs
show what each design costs.

## Why this exists

Signup is the classic case where the natural Rails reflex goes wrong. It feels like
"creating a User", so the rules end up on `User`:

- the user must accept the terms of service
- the password must be confirmed and meet a strength policy
- one form spans two models (`Account` + its first `User`)

But none of these are properties of a user. They are properties of **the signup flow**.
Once they're on the model, every other way of creating a user has to satisfy them too:
an admin inviting a teammate, seeds, a console session, a CSV import. The usual fix,
`attr_accessor :signing_up` plus `if: :signing_up?` on the validations, adds a flag to
the model for every flow it's used in.

A **Form Object** is a plain Ruby object (`ActiveModel::Model` + `ActiveModel::Attributes`)
that represents one user-facing flow. It owns that flow's validations, can span any
number of models, and persists them explicitly in a transaction. The models keep only
the invariants that hold on every path.

| | Form Object (`SignupForm`) | `accepts_nested_attributes_for` + callbacks |
|---|---|---|
| Where flow rules live | In the form, scoped to signup | On the models, applied to every create |
| Spanning multiple models | Explicit, in one transaction | Implicit, through nested params |
| Error keys | Flat, matching the fields (`:email`) | Association paths (`:"users.email"`) |
| Side effects | Explicit lines in `#save` | Callbacks that fire on every create |
| Params shape | Flat: `signup[email]` | Nested: `account[users_attributes][0][email]` |
| Other creation paths (admin, seeds) | Unaffected | Must fake signup fields or add flags |
| Boilerplate | A class per flow | Close to none |

## What's in this repo

### 1. `SignupForm`: single-page signup ([app/forms/signup_form.rb](app/forms/signup_form.rb))

Creates an `Account` and its first `User` in one transaction. What to look at:

- **Signup-only rules live in the form.** Terms acceptance, password confirmation and
  length, and email format are validated here. [`User`](app/models/user.rb) keeps only
  presence and a normalized, unique email, backed by `NOT NULL` and a unique index.
- **Write-time errors are promoted to the form.** Some model invariants can only fail on
  write, like an email taken between validation and insert. `#save` rescues
  `RecordInvalid`, copies the model's errors onto the form's matching fields, and the
  transaction rolls back the `Account`.
- **`model_name` is overridden** so params arrive as `params[:signup]`, not
  `params[:signup_form]`.
- A spec creates a `User` without going through the form, to prove the signup rules
  stay out of the model.

### 2. `SignupWizard`: the same signup as a multi-step flow ([app/forms/signup_wizard.rb](app/forms/signup_wizard.rb))

Three steps, `/wizard/account` → `/wizard/profile` → `/wizard/credentials`:

- **No rule is redefined.** Each step runs `SignupForm`'s validations and keeps only the
  errors for its own fields. The single-page and multi-step flows can never disagree
  about what a valid signup is.
- **The password is never stored in the session.** Earlier steps' answers are kept in the
  session between requests. Credentials are on the last step on purpose, so they go
  straight from the request to `has_secure_password`. Even with Rails' encrypted cookie
  store, a plaintext password shouldn't sit in a cookie.
- **Write-time errors send you back to the step that owns the field.** If the email is
  taken on final submit, you land on the `profile` step with the error on the field, not
  on the password page.
- **Steps can't be skipped.** Requesting a later step's URL redirects to the first
  earlier step that isn't valid with what's stored. Unknown steps return 404 via a route
  constraint.

### 3. `NestedSignup`: the counterpoint ([app/models/nested_signup/](app/models/nested_signup/))

The same signup done the "fat model" way: `NestedSignup::Account` has
`accepts_nested_attributes_for :users`, the signup rules are validations on
`NestedSignup::User`, and there's an `after_create_commit` "signup" callback. These
classes are namespaced and point at the same tables, so they don't leak into the real
`Account`/`User`.

[spec/models/nested_signup/account_spec.rb](spec/models/nested_signup/account_spec.rb)
has one example per cost:

- Errors are keyed on the association (`:"users.email"`), so full messages read
  "Users email has already been taken".
- Without `limit: 1`, a client can post many `users_attributes` entries and create that
  many users in one signup. With the limit, the request raises `TooManyRecords`, which
  the controller doesn't rescue here, so the extra entries produce a 500.
- An `Account` can no longer be created without a user, which breaks seeds and admin
  tools.
- Inviting a user to an existing account fails unless you fake `terms_of_service` and
  `password_confirmation`.
- The "signup" callback runs on every `Account` creation, not just signups.

## Gotcha worth knowing: `acceptance` and `confirmation` skip `nil`

Both validators pass when the attribute is `nil`: `acceptance` defaults to
`allow_nil: true`, and `confirmation` only runs when the confirmation field is present.
Browsers hide the problem, because `check_box` always sends a hidden `"0"` and password
fields always submit. But a client that **omits** the fields entirely (curl, an API
client, a script) passes validation and signs up without accepting the terms or
confirming the password.

This lab had exactly that bug in its first version of `SignupForm`. The fix:

```ruby
validates :password_confirmation, presence: true, if: -> { password.present? }
validates :terms_of_service, acceptance: { accept: true, allow_nil: false }
```

It's covered by specs that remove the fields from the request on purpose.

## Where does a rule belong?

A rough heuristic used throughout this repo:

- **Model:** rules that must hold no matter who writes the row, such as presence of
  required columns and uniqueness. Back them with database constraints (`NOT NULL`,
  unique indexes), because validations alone lose races.
- **Form object:** rules that only make sense in one flow, such as terms acceptance,
  confirmation fields, a step order, or a side effect that belongs to "signing up"
  rather than to "a row being inserted".
- **Neither:** a callback that sends emails or calls external services from the model.
  Make it an explicit step of the flow that needs it.

## When `accepts_nested_attributes_for` is fine

Nested attributes aren't wrong. They fit when the nested records are genuinely part of
the parent and the rules hold on every path: editing an invoice and its line items, or
a survey and its questions. The trouble starts when a flow-specific rule gets attached to
a model that is also created elsewhere.

## Running it

```bash
bin/setup      # installs gems, prepares the database, starts the server
bin/dev        # or start the server on its own
open http://localhost:3000

bundle exec rspec
bin/ci         # rubocop, bundler-audit, importmap audit, brakeman and rspec
```

The home page links to all three flows.

## Stack

Rails 8.1, SQLite, Hotwire (Turbo + Stimulus via importmap), RSpec + shoulda-matchers.

---

This is one of a set of small labs exploring backend/Rails concepts in isolation before
combining them in a larger integrated project:

- `pagination-lab`: offset vs cursor pagination
- `hotwire-realtime-demo`: Turbo Streams + ActionCable real-time UI
- `form-objects-playground` (this repo): Form Objects for multi-step and multi-model flows
- `db-locking-lab`: optimistic vs pessimistic locking under concurrency
