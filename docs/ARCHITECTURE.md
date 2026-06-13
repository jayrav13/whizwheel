# whizwheel — Architecture & Conventions

**Status:** Living document. This is the **single source of truth for how whizwheel is built.** Every agent (backend, frontend) ingests this before producing code; every feature spec references it. When the vision changes, it changes *here* first.

**Date started:** 2026-06-13

---

## 0. The ontology (words we use precisely)

| Term | Means | Lives as |
|---|---|---|
| **Calculator** | A *type* — the page, the math, the engineering artifact. e.g. "Percentage". | Code: `Calculators::Percentage`. Catalogued in the PM's `docs/inventory.md`. Keyed by a **slug** (`"percentage"`). |
| **Calculation** | A single *run* of a calculator — one invocation, with its inputs and result. | A DB row: `Calculation` (ActiveRecord). |
| **calculation_logs** | A denormalized read model for reporting/stats. | A DB **view** over `calculations`. |

Calculators are **code, not data** — there is no `calculators` table. Adding a calculator is engineering work (a file), not a database insert.

---

## 1. The layering (the spine)

```
request → CalculatorsController → Calculators::X (pure math) ─┐
                  │                                            │ builds (unsaved)
                  │                                            ▼
                  │                                       Calculation.new(...)
                  ├── persists now: record.save  ── or ── later: RecordCalculationJob
                  └── renders JSON  ◀── from the computed result, NOT the saved row
```

Each layer is independently testable and has one job:
- **`Calculators::X`** — math + input validation. No database, no request, no user. Returns a result and can build an **unsaved** `Calculation`.
- **Controller** — orchestrates: build the calculator, validate, persist the calculation, render.
- **Persistence** — the controller saves the record *today*; under load this becomes a background job (eventual consistency) with **no change to the response or the contract**, because the response is derived from the computed result, not from persistence succeeding.

---

## 2. Calculators — `app/calculators/`

A dedicated autoload root, namespaced `Calculators::` via one initializer:

```ruby
# config/initializers/calculators.rb
Rails.autoloaders.main.push_dir(Rails.root.join("app/calculators"), namespace: Calculators)
```

So `app/calculators/percentage.rb` → `Calculators::Percentage` (single directory, clean names).

**The base class** establishes the contract — an ActiveModel object (typed attributes + validations), a memoized `result`, a `slug`, and the unsaved-record builder:

```ruby
# app/calculators/base.rb  → Calculators::Base
module Calculators
  class Base
    include ActiveModel::Model
    include ActiveModel::Attributes

    def self.slug = name.demodulize.underscore          # Calculators::Percentage → "percentage"
    def self.lookup(slug) = "Calculators::#{slug.to_s.camelize}".safe_constantize

    # Subclasses MUST implement #compute and return a Hash.
    def result
      @result ||= (compute if valid?)
    end

    # An UNSAVED Calculation. Touches no database; assigns no user.
    def to_calculation
      Calculation.new(calculator: self.class.slug, inputs: attributes, result: result)
    end

    private

    def compute = raise(NotImplementedError)
  end
end
```

**A concrete calculator** (the Percentage vehicle):

```ruby
# app/calculators/percentage.rb  → Calculators::Percentage
module Calculators
  class Percentage < Base
    attribute :base, :decimal
    attribute :rate, :decimal
    validates :base, :rate, presence: true, numericality: true

    private

    def compute
      { value: base * rate / 100 }
    end
  end
end
```

**Why ActiveModel, not a bare PORO:** declarative `validates`, automatic string→`BigDecimal` coercion (`"20"` → exact decimal), and a structured `errors` object — all the validation ergonomics, **no database**.

---

## 3. Routing — one dynamic route (auto-discovery, fan-out-safe)

```ruby
# config/routes.rb
post "/calculators/:slug", to: "calculators#create"
```

```ruby
# app/controllers/calculators_controller.rb
class CalculatorsController < ApplicationController
  def create
    klass = Calculators::Base.lookup(params[:slug])
    return head(:not_found) unless klass

    calc = klass.new(calculator_params)
    if calc.valid?
      record = calc.to_calculation
      record.user = Current.user      # may be nil — anonymous calculations are allowed
      record.save                     # ← the only persistence point; later: a job
      render json: envelope_ok(klass, calc)
    else
      render json: envelope_invalid(klass, calc), status: :unprocessable_entity
    end
  end

  private

  def calculator_params = params.fetch(:inputs, {}).permit!  # calculators validate their own attrs
end
```

**Adding a calculator never edits `routes.rb`, a controller, or a registry** — you drop one file in `app/calculators/`. That is the auto-discovery property that keeps parallel/fan-out builds conflict-free. It is a hard rule: **no central registration of calculators.**

---

## 4. The JSON contract (the backend↔frontend seam)

**Request** — inputs are nested under `inputs` so they map cleanly to the calculator's attributes:

```jsonc
// POST /calculators/percentage
{ "inputs": { "base": "50", "rate": "20" } }
```

**Response** — one envelope, identical for every calculator:

```jsonc
// 200 — success
{ "ok": true,  "calculator": "percentage", "inputs": { "base": "50", "rate": "20" }, "result": { "value": "10.0" } }

// 422 — invalid input
{ "ok": false, "calculator": "percentage", "errors": { "base": ["is not a number"] } }

// 404 — unknown calculator slug
```

```ruby
def envelope_ok(klass, calc)      = { ok: true,  calculator: klass.slug, inputs: calc.attributes, result: calc.result }
def envelope_invalid(klass, calc) = { ok: false, calculator: klass.slug, errors: calc.errors.to_hash }
```

The frontend agent codes against this envelope and nothing else.

---

## 5. `Calculation` + the `calculation_logs` view

**Write model** — normalized, with the only real FK on `user`:

```ruby
# app/models/calculation.rb
class Calculation < ApplicationRecord
  include Discardable
  belongs_to :user, optional: true   # nullable — anonymous calculations allowed
end
```

```ruby
# migration
create_table :calculations do |t|
  t.references :user, foreign_key: true, null: true
  t.string  :calculator, null: false          # the slug; NOT a FK (calculators are code)
  t.jsonb   :inputs,  null: false, default: {}
  t.jsonb   :result,  null: false, default: {}
  t.datetime :deleted_at
  t.timestamps
end
add_index :calculations, :calculator
add_index :calculations, :deleted_at
```

**Read model** — `calculation_logs` is a DB **view** joining `calculations ⨝ users` to denormalize (e.g. surface `username`) for reporting. Plain view first (always live); promote to materialized only if stats get heavy. Managed via a migration (the `scenic` gem is the clean way to version views, but a raw `execute "CREATE VIEW …"` is acceptable).

**Recording lifecycle:** the controller saves `record` today. Under load, replace `record.save` with `RecordCalculationJob.perform_later(record.attributes)` — eventual consistency, response unchanged.

---

## 6. Soft-delete convention

Nothing user-facing is ever hard-deleted. One concern, applied wherever "delete" is offered:

```ruby
# app/models/concerns/discardable.rb
module Discardable
  extend ActiveSupport::Concern
  included do
    scope :kept,      -> { where(deleted_at: nil) }
    scope :discarded, -> { where.not(deleted_at: nil) }
  end
  def discard    = update!(deleted_at: Time.current)
  def undiscard  = update!(deleted_at: nil)
  def discarded? = deleted_at.present?
end
```

Applied to **`Calculation`** and **`Role`** (and `RoleType`). Query rules:
- **Per-user** history/stats → `Calculation.kept.where(user:)` — a user's discarded rows are hidden from them.
- **Site-wide** admin stats → the **full** table/view (discarded included) — *usage is usage*; a user hiding their own history must not erode site-wide totals.

---

## 7. Authentication (adapted Rails 8 built-in)

Start from `bin/rails generate authentication`, then adapt:
- **`User`**: `username` (unique) + `password_digest` (`has_secure_password`). **No email.**
- **`Session`**, **`Current`** as generated.
- **Removed:** the password-reset mailer flow, and **all registration** — there is no sign-up UI.
- Authentication is **login/logout only**. Users arrive via DB insert / the CLI tasks (§9).

Anonymous visitors may use calculators (§3); when signed in, the calculation is attributed to them.

---

## 8. Authorization (RBAC)

```ruby
class RoleType < ApplicationRecord   # display_name:string, permalink:string
  include Discardable
  has_many :roles
end

class Role < ApplicationRecord       # belongs_to user + role_type
  include Discardable
  belongs_to :user
  belongs_to :role_type
end

# app/models/user.rb
def admin?
  roles.kept.joins(:role_type).where(role_types: { permalink: "ADMIN", deleted_at: nil }).exists?
end
```

- `RoleType` is **seeded reference data**; one row to start: `{ display_name: "Admin", permalink: "ADMIN" }`.
- Granting admin = creating a `Role(user, ADMIN)`. Revoking = **discarding** that `Role` (audit trail preserved).
- The ADMIN role **gates** the site-wide stats (an admin `before_action`). 
- **No user/role management UI** for now — roles are DB/CLI-managed (§9). (A future spec may add admin-management UIs.)

---

## 9. User & role management — CLI only

The app has no web surface for creating users or roles. Management is Ruby rake tasks:

```bash
bin/rails "users:create[alice]"       # create a user (set password)
bin/rails "users:set_password[alice]" # the "reset" — sets a new digest, no email/token
bin/rails "admins:grant[alice]"       # create a Role(user, ADMIN)
bin/rails "admins:revoke[alice]"      # discard that Role
```

---

## 10. Precision & rounding

- All decimal math uses **`BigDecimal`** (ActiveModel `:decimal` attributes), so `0.1 + 0.2 == 0.3` exactly — no float drift.
- Compute at full precision; **round only for display**, per-calculator (money → 2dp, half-up). A result may carry both the raw value and a formatted form.
- Correctness is pinned by **reference-value tests** (§11) against calculator.net.

---

## 11. Testing & CI (the 100% gate)

Framework: **Minitest** (Rails default), fixtures, parallelized.

- **Every calculator** ships a unit test with a **reference-value table** — `{inputs} → {expected}` rows taken from calculator.net — plus validation cases. The calculator's purity (no DB, no request) makes this trivial and exhaustive.
- **`Calculation`/recording** and **controllers** are tested separately (controller integration tests cover success, validation, the JSON envelope, anonymous vs. attributed, and that a row is recorded).
- **Coverage gate:** SimpleCov with `minimum_coverage 100` in `test/test_helper.rb` — the build **fails below 100%**. Wired into the existing `test` job in `.github/workflows/ci.yml`.

```ruby
# top of test/test_helper.rb
require "simplecov"
SimpleCov.start "rails" do
  minimum_coverage 100
end
```

**CI health note:** the suite currently fails only because `db/schema.rb` doesn't exist yet (a fresh app with zero migrations). The **first migration** (auth/`calculations`) creates the schema and turns `test`, `system-test`, and the dependabot PRs green. No separate CI fix is needed.

---

## 12. Standing conventions (the short list)

1. **Calculators are code, append-only.** Never delete a calculator — **deprecate** it — so historical `calculations` keep their comparability.
2. **No central registration.** A calculator is discoverable by existing as a file; nothing shared (`routes.rb`, a registry, a table) is edited to add one. This is what keeps parallel/fan-out builds conflict-free.
3. **Soft-delete, never hard-delete** user-facing data.
4. **Responses are decoupled from persistence** — recording is a side effect, swappable for a job.
5. **The math layer is pure** — no DB, no request, no user — which is what makes 100% coverage achievable.

---

## 13. Out of scope here (downstream feature specs)

This doc is *conventions*, not features. Each of these gets its own spec → plan → build:
- **App foundation** — auth, RBAC, the `Calculation` model + view, the `Discardable` concern, the CLI tasks, the first migration (→ green CI).
- **User history & stats page** — per-user usage + history, soft-delete an item / delete-all.
- **Admin site-wide stats** — the ADMIN-gated usage dashboard.
- **The backend agent** — lean; instructed to read *this doc* and build calculators on this foundation.
- **The frontend agent** and the calculators themselves.
