# whizwheel — Architecture & Conventions

**Status:** Living document. This is the **single source of truth for how whizwheel is built.** Every agent (backend, frontend) ingests this before producing code; every feature spec references it. When the vision changes, it changes *here* first.

**Date started:** 2026-06-13

---

## 0. The ontology (words we use precisely)

| Term | Means | Lives as |
|---|---|---|
| **Calculator** | A *type* — the page, the math, the engineering artifact. e.g. "Percentage". | Code: `Calculators::Percentage`. Catalogued in the PM's `docs/inventory.md`. Keyed by a **slug** (`"percentage"`). |
| **Spec** | The durable *intent* of a calculator — what it must do, its inputs/outputs, reference values — that the agents regenerate the implementation **from** (see §3.1). The code is a *production of* the spec, not the reverse. | **TBD** — its exact format and home are settled when the backend agent is built (issue #6); today it is half-implied by the calculator's `engineering` issue body + its `inventory.md` row. |
| **Calculation** | A single *run* of a calculator — one invocation, with its inputs and result. | A DB row: `Calculation` (ActiveRecord). |
| **calculation_logs** | A denormalized read model for reporting/stats. | A DB **view** over `calculations`. |

Calculators are **code, not data** — there is no `calculators` table. Adding a calculator is engineering work (a file), not a database insert. And that code is **regenerated from the spec each iteration** (§3.1), never hand-refactored in place.

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

## 3.1 The build model — regenerate from spec, by fan-out sweep

How calculators come into being, as durable convention. (The iteration mechanics — opening, logging, closing — live in the PM agent's Iterations capability; this is the engineering shape it rests on.)

**The spec is the first-class, durable artifact.** Each calculator has a **spec** (§0) — its intent, inputs/outputs, and reference values — and the build agents regenerate the **implementation from that spec**. "Rebuild" therefore means **regenerate-from-spec**, *never* refactor-the-existing-code: a rebuilt calculator is an independent production of the current agents, not an edit of the prior one. Its diff against the previous version is then a clean, controlled A/B on the agents — exactly the signal the experiment is trying to read.

> **Spec format/home is deliberately OPEN.** The spec artifact's concrete shape — file format, schema, directory — is **TBD, to be settled when the backend agent is built (issue #6)**. Today it is only half-implied (the calculator's `engineering` issue body + its `inventory.md` row). We are intentionally not over-specifying it ahead of the first calculator.

**Builds happen as a fan-out sweep.** An iteration both adds the next `n` new calculators **and regenerates every previously-built one** with the pinned agent set — one agent invocation per calculator. This is conflict-free precisely because of §2–3: each calculator owns its own file and there is **no central registration**, so N agents can run in parallel without colliding on `routes.rb`, a registry, or a shared table. The FE/BE build agents are thus **parameterized, fan-out-able workers** (one calculator each), suited to dynamic-workflow orchestration.

**This is what makes the agent-first rule enforceable.** Because every prior calculator is regenerated from its spec each sweep, any fix that lives **only in calculator code** — never lifted up into the agent definition, the spec, or the tests — is **erased** by the next sweep. That forces every durable decision up into the agent/spec/test layer, which is the whole point (`CLAUDE.md` rule #1; calculators are append-only per §12, so prior versions remain comparable). Cross-reference: `project-manager-agent.md` (the Iterations capability — how a sweep is opened, logged, and closed).

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

**Every feature ships tests — no feature merges without them.** Which tests depends on the layer(s) the feature touches:

| Layer | Test type | What it covers |
|---|---|---|
| **Math (calculators)** | **unit + reference-value table** | `{inputs} → {expected}` rows from calculator.net + validation cases. The calculator's purity (no DB, no request) makes this exhaustive. |
| **Persistence / controllers** | **integration** | `Calculation`/recording and controllers — success, validation, the JSON envelope, anonymous vs. attributed, that a row is recorded. |
| **UI (views/pages)** | **integration** (render + states) **+ system + full-page screenshots** | each page renders and its key states are correct, plus a **visual self-review** (below). |

### Backend work
- **Every calculator** ships a reference-value unit test (the table above) + validation cases.
- **`Calculation`/recording** and **controllers** get integration tests.

### Frontend work
- **Integration tests** assert each page renders and its key states (e.g. signed-in vs. signed-out, error/flash states).
- **System tests + full-page screenshots are required for any new/changed page.** Use `ApplicationSystemTestCase#screenshot_full_page` (headless Chrome; grows the window to the full document height); the test drives the page and saves a PNG to `tmp/screenshots/`.
- **Visual self-review (mandatory):** run `bin/rails tailwindcss:build && NO_COVERAGE=1 bin/rails test:system`, then **look at the resulting `tmp/screenshots/*.png` against `DESIGN.md`** (tokens, spacing, the green's placement, the overall look) before handing off. ERB is not coverage-counted, so this screenshot review — not coverage — is how UI quality is verified. The visual review has **two homes**: this **local** self-review, and a **CI-artifact** review during PR monitoring — CI produces the same shots as the `ui-screenshots` artifact, pulled with `bin/ci-screenshots --pr <n>`; the CI/Linux render is a proxy for non-Mac visitors and catches cross-platform issues (e.g. font fallback) the local render hides. **Every** shot is reviewed (a `--baseline` sha256 diff makes "unchanged" deterministic) — never a sample. Human visual review follows; the screenshots are the shared artifact. (Operationalized in `.claude/agents/frontend.md`; the CI gate in `CLAUDE.md` → CI/CD monitoring.)

### The coverage gate
- **SimpleCov, 100% line + branch**, enforced on the unit/integration suite (`bin/rails test`) — the build **fails below 100%**. It counts **Ruby** (calculators, models, controllers, helpers); **ERB views are not counted**.
- The **system-test pass runs separately** (`bin/rails test:system`) and opts out of the gate via **`NO_COVERAGE`** (a browser pass can't exercise every line on its own); the unit `test` job stays the gate.

```ruby
# top of test/test_helper.rb
require "simplecov"
SimpleCov.start "rails" do
  enable_coverage :branch
  add_filter "/test/"
  add_filter "/config/"
  minimum_coverage line: 100, branch: 100 unless ENV["NO_COVERAGE"]
end
```

**CI** (`.github/workflows/ci.yml`): the **`test`** job runs the gated unit/integration suite; the **`system-test`** job runs the browser/screenshot tests with `NO_COVERAGE` and **uploads the screenshots as artifacts**. Both build CSS first (`bin/rails tailwindcss:build`) so Propshaft can resolve the Tailwind stylesheet the layout links.

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
