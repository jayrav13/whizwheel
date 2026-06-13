# App Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Each implementer subagent MUST first read `docs/ARCHITECTURE.md` and `CLAUDE.md` — they encode the project's style and rules. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Build the non-calculator app foundation — soft-delete, authentication, RBAC, the `Calculation` persistence layer + reporting view, CLI user/role management, and a 100% test-coverage gate — so the backend agent has a platform to build calculators on.

**Architecture:** Per `docs/ARCHITECTURE.md`. Session-based auth (username/password, no email/reset/signup). Soft-delete via a `Discardable` concern. RBAC via `RoleType`/`Role`. `Calculation` is a soft-deletable AR model; `calculation_logs` is a Postgres view. Schema format is already `:sql` (`db/structure.sql`). Minitest + fixtures, strict TDD, plain `git commit` with the `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` trailer.

**Tech Stack:** Rails 8.1, Ruby 3.4, PostgreSQL (jsonb + a view), bcrypt, SimpleCov.

**OUT OF SCOPE** (the backend agent builds these, not this plan): `Calculators::Base`, `CalculatorsController`, the `/calculators/:slug` route, the calculators autoload initializer, and any calculator.

**Coverage note:** SimpleCov measures Ruby under `app/` + `lib/` (not ERB views). The 100% gate is wired in the **final task**, after all code+tests exist; every task is TDD'd so the gate passes at the end. If the final task finds <100%, add tests for the exact uncovered lines.

---

## File Structure

| File | Responsibility |
|---|---|
| `app/models/concerns/discardable.rb` | Soft-delete: `deleted_at`, `discard`/`undiscard`/`discarded?`, `kept`/`discarded` scopes |
| `app/models/user.rb` | `has_secure_password`, sessions, roles, `#admin?` |
| `app/models/session.rb` | A login session (belongs_to user) |
| `app/models/current.rb` | `Current.session` / `Current.user` |
| `app/models/role_type.rb` | Seeded role kinds (ADMIN); discardable |
| `app/models/role.rb` | User↔RoleType assignment; discardable |
| `app/models/calculation.rb` | One calculation run; discardable |
| `app/controllers/concerns/authentication.rb` | Session resume / start / terminate; `current_user` |
| `app/controllers/sessions_controller.rb` | Login (new/create) + logout (destroy) |
| `app/controllers/home_controller.rb` | Minimal root page (placeholder for the frontend agent) |
| `lib/tasks/users.rake`, `lib/tasks/admins.rake` | CLI user/role management |
| `db/migrate/*` | users, sessions, role_types, roles, calculations, calculation_logs view |
| `db/seeds.rb` | Seed the ADMIN `RoleType` |
| `test/...` | Minitest tests + fixtures for all of the above |

---

## Task 1: Authentication (User, Session, Current, login)

**Files:**
- Create: `app/models/user.rb`, `app/models/session.rb`, `app/models/current.rb`
- Create: `app/controllers/concerns/authentication.rb`, `app/controllers/sessions_controller.rb`, `app/controllers/home_controller.rb`
- Create: `app/views/sessions/new.html.erb`, `app/views/home/index.html.erb`
- Create migrations: users, sessions
- Modify: `Gemfile` (enable bcrypt), `config/routes.rb`, `app/controllers/application_controller.rb`
- Test: `test/models/user_test.rb`, `test/integration/authentication_test.rb`, fixtures `test/fixtures/users.yml`, `test/fixtures/sessions.yml`

- [ ] **Step 1: Enable bcrypt**

In `Gemfile`, change the commented line `# gem "bcrypt", "~> 3.1.7"` to active:
```ruby
gem "bcrypt", "~> 3.1.7"
```
Run: `bundle install`
Expected: bundle resolves with bcrypt.

- [ ] **Step 2: Generate the migrations**

Run:
```bash
bin/rails generate migration CreateUsers username:string:uniq password_digest:string
bin/rails generate migration CreateSessions user:references ip_address:string user_agent:string
```
Then edit the **users** migration so `username` is `null: false` and the index is unique, and `password_digest` is `null: false`. Final users migration `change` body:
```ruby
create_table :users do |t|
  t.string :username, null: false
  t.string :password_digest, null: false
  t.timestamps
end
add_index :users, :username, unique: true
```
Sessions migration `change` body:
```ruby
create_table :sessions do |t|
  t.references :user, null: false, foreign_key: true
  t.string :ip_address
  t.string :user_agent
  t.timestamps
end
```

- [ ] **Step 3: Write the failing model test**

`test/models/user_test.rb`:
```ruby
require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "requires a unique username" do
    dup = User.new(username: users(:alice).username, password: "secret123")
    assert_not dup.valid?
    assert_includes dup.errors[:username], "has already been taken"
  end

  test "normalizes username to stripped lowercase" do
    user = User.create!(username: "  BoB  ", password: "secret123")
    assert_equal "bob", user.username
  end

  test "authenticate_by verifies the password" do
    assert User.authenticate_by(username: "alice", password: "password")
    assert_nil User.authenticate_by(username: "alice", password: "wrong")
  end
end
```
Fixtures `test/fixtures/users.yml`:
```yaml
alice:
  username: alice
  password_digest: <%= BCrypt::Password.create("password") %>
```
Fixtures `test/fixtures/sessions.yml`:
```yaml
alice_session:
  user: alice
  ip_address: 127.0.0.1
  user_agent: test
```

- [ ] **Step 4: Run the test, watch it fail**

Run: `bin/rails db:migrate && bin/rails test test/models/user_test.rb`
Expected: FAIL — `User` is not defined / table missing.

- [ ] **Step 5: Implement the models**

`app/models/user.rb`:
```ruby
class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :username, with: ->(u) { u.strip.downcase }
  validates :username, presence: true, uniqueness: true
end
```
`app/models/session.rb`:
```ruby
class Session < ApplicationRecord
  belongs_to :user
end
```
`app/models/current.rb`:
```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :session
  delegate :user, to: :session, allow_nil: true
end
```

- [ ] **Step 6: Run the model test, watch it pass**

Run: `bin/rails test test/models/user_test.rb`
Expected: PASS (3 tests).

- [ ] **Step 7: Implement auth controllers + routes (failing integration test first)**

`test/integration/authentication_test.rb`:
```ruby
require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "root page renders for anonymous visitors" do
    get root_path
    assert_response :success
    assert_select "body", /not signed in/i
  end

  test "valid login starts a session and shows the username" do
    post session_path, params: { username: "alice", password: "password" }
    assert_redirected_to root_path
    follow_redirect!
    assert_select "body", /alice/
  end

  test "invalid login is rejected" do
    post session_path, params: { username: "alice", password: "nope" }
    assert_redirected_to new_session_path
  end

  test "logout terminates the session" do
    post session_path, params: { username: "alice", password: "password" }
    delete session_path
    assert_redirected_to root_path
    follow_redirect!
    assert_select "body", /not signed in/i
  end
end
```

- [ ] **Step 8: Run it, watch it fail**

Run: `bin/rails test test/integration/authentication_test.rb`
Expected: FAIL — routes/controllers undefined.

- [ ] **Step 9: Implement the concern, controllers, views, routes**

`app/controllers/concerns/authentication.rb`:
```ruby
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :resume_session
    helper_method :authenticated?, :current_user
  end

  private

  def authenticated? = Current.session.present?
  def current_user = Current.user

  def resume_session
    Current.session ||= find_session_by_cookie
  end

  def find_session_by_cookie
    Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
  end

  def start_new_session_for(user)
    user.sessions.create!(ip_address: request.remote_ip, user_agent: request.user_agent).tap do |session|
      Current.session = session
      cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
    end
  end

  def terminate_session
    Current.session&.destroy
    cookies.delete(:session_id)
    Current.session = nil
  end
end
```
`app/controllers/application_controller.rb` — add `include Authentication`:
```ruby
class ApplicationController < ActionController::Base
  include Authentication
  allow_browser versions: :modern
  stale_when_importmap_changes
end
```
`app/controllers/sessions_controller.rb`:
```ruby
class SessionsController < ApplicationController
  def new
  end

  def create
    if (user = User.authenticate_by(username: params[:username], password: params[:password]))
      start_new_session_for(user)
      redirect_to root_path
    else
      redirect_to new_session_path, alert: "Invalid username or password."
    end
  end

  def destroy
    terminate_session
    redirect_to root_path
  end
end
```
`app/controllers/home_controller.rb` (placeholder root — the frontend agent replaces this):
```ruby
class HomeController < ApplicationController
  def index
  end
end
```
`app/views/sessions/new.html.erb`:
```erb
<h1>Sign in</h1>
<%= form_with url: session_path, method: :post do |f| %>
  <%= f.text_field :username, autocomplete: "username" %>
  <%= f.password_field :password, autocomplete: "current-password" %>
  <%= f.submit "Sign in" %>
<% end %>
```
`app/views/home/index.html.erb`:
```erb
<% if current_user %>
  <p>Signed in as <%= current_user.username %>. <%= button_to "Sign out", session_path, method: :delete %></p>
<% else %>
  <p>You are not signed in. <%= link_to "Sign in", new_session_path %></p>
<% end %>
```
`config/routes.rb` — add inside the draw block:
```ruby
root "home#index"
resource :session, only: %i[new create destroy]
```

- [ ] **Step 10: Run the integration test, watch it pass**

Run: `bin/rails test test/integration/authentication_test.rb`
Expected: PASS (4 tests).

- [ ] **Step 11: Commit**

```bash
git add app/models/user.rb app/models/session.rb app/models/current.rb \
  app/controllers/concerns/authentication.rb app/controllers/sessions_controller.rb \
  app/controllers/home_controller.rb app/controllers/application_controller.rb \
  app/views/sessions app/views/home config/routes.rb Gemfile Gemfile.lock \
  db/migrate db/structure.sql \
  test/models/user_test.rb test/integration/authentication_test.rb \
  test/fixtures/users.yml test/fixtures/sessions.yml
git commit -m "$(printf 'feat: session-based username/password authentication\n\nCo-Authored-By: Claude Fable 5 <noreply@anthropic.com>')"
```

---

## Task 2: Soft-delete (Discardable) + RBAC

**Files:**
- Create: `app/models/concerns/discardable.rb`, `app/models/role_type.rb`, `app/models/role.rb`
- Modify: `app/models/user.rb` (add roles + `#admin?`), `db/seeds.rb`
- Create migrations: role_types, roles
- Test: `test/models/role_test.rb`, `test/models/discardable_test.rb`, fixtures `role_types.yml`, `roles.yml`

- [ ] **Step 1: Generate migrations**

```bash
bin/rails generate migration CreateRoleTypes display_name:string permalink:string:uniq deleted_at:datetime
bin/rails generate migration CreateRoles user:references role_type:references deleted_at:datetime
```
Ensure the role_types migration marks `display_name` and `permalink` `null: false` and the permalink index unique. role_types `change`:
```ruby
create_table :role_types do |t|
  t.string :display_name, null: false
  t.string :permalink, null: false
  t.datetime :deleted_at
  t.timestamps
end
add_index :role_types, :permalink, unique: true
```
roles `change`:
```ruby
create_table :roles do |t|
  t.references :user, null: false, foreign_key: true
  t.references :role_type, null: false, foreign_key: true
  t.datetime :deleted_at
  t.timestamps
end
```

- [ ] **Step 2: Write failing tests**

`test/models/discardable_test.rb` (tests the concern through `Role`):
```ruby
require "test_helper"

class DiscardableTest < ActiveSupport::TestCase
  test "discard sets deleted_at and removes from kept" do
    role = roles(:alice_admin)
    assert_includes Role.kept, role
    role.discard
    assert role.discarded?
    assert_not_includes Role.kept, role
    assert_includes Role.discarded, role
  end

  test "undiscard restores" do
    role = roles(:alice_admin)
    role.discard
    role.undiscard
    assert_not role.discarded?
    assert_includes Role.kept, role
  end
end
```
`test/models/role_test.rb`:
```ruby
require "test_helper"

class RoleTest < ActiveSupport::TestCase
  test "user is admin with a kept ADMIN role" do
    assert users(:alice).admin?
  end

  test "user is not admin once the role is discarded" do
    roles(:alice_admin).discard
    assert_not users(:alice).reload.admin?
  end

  test "user without an admin role is not admin" do
    assert_not users(:bob).admin?
  end
end
```
Fixtures — append to `test/fixtures/users.yml`:
```yaml
bob:
  username: bob
  password_digest: <%= BCrypt::Password.create("password") %>
```
`test/fixtures/role_types.yml`:
```yaml
admin:
  display_name: Admin
  permalink: ADMIN
```
`test/fixtures/roles.yml`:
```yaml
alice_admin:
  user: alice
  role_type: admin
```

- [ ] **Step 3: Run, watch fail**

Run: `bin/rails test test/models/role_test.rb test/models/discardable_test.rb`
Expected: FAIL — `Discardable`/`Role`/`admin?` undefined.

- [ ] **Step 4: Implement**

`app/models/concerns/discardable.rb`:
```ruby
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
`app/models/role_type.rb`:
```ruby
class RoleType < ApplicationRecord
  include Discardable
  has_many :roles, dependent: :destroy
  validates :display_name, :permalink, presence: true
  validates :permalink, uniqueness: true
end
```
`app/models/role.rb`:
```ruby
class Role < ApplicationRecord
  include Discardable
  belongs_to :user
  belongs_to :role_type
end
```
`app/models/user.rb` — add associations + `#admin?`:
```ruby
class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :roles, dependent: :destroy

  normalizes :username, with: ->(u) { u.strip.downcase }
  validates :username, presence: true, uniqueness: true

  def admin?
    roles.kept.joins(:role_type).where(role_types: { permalink: "ADMIN", deleted_at: nil }).exists?
  end
end
```
`db/seeds.rb` — append:
```ruby
RoleType.find_or_create_by!(permalink: "ADMIN") { |rt| rt.display_name = "Admin" }
```

- [ ] **Step 5: Run, watch pass**

Run: `bin/rails db:migrate && bin/rails test test/models/role_test.rb test/models/discardable_test.rb`
Expected: PASS (5 tests).

- [ ] **Step 6: Commit**

```bash
git add app/models/concerns/discardable.rb app/models/role_type.rb app/models/role.rb \
  app/models/user.rb db/seeds.rb db/migrate db/structure.sql \
  test/models/role_test.rb test/models/discardable_test.rb \
  test/fixtures/role_types.yml test/fixtures/roles.yml test/fixtures/users.yml
git commit -m "$(printf 'feat: soft-delete concern and RBAC (RoleType/Role, admin?)\n\nCo-Authored-By: Claude Fable 5 <noreply@anthropic.com>')"
```

---

## Task 3: Calculation model + calculation_logs view

**Files:**
- Create: `app/models/calculation.rb`
- Create migrations: calculations, the calculation_logs view
- Test: `test/models/calculation_test.rb`, fixtures `calculations.yml`

- [ ] **Step 1: Generate the calculations migration**

```bash
bin/rails generate migration CreateCalculations user:references calculator:string deleted_at:datetime
```
Edit its `change` to make `user` nullable, `calculator` non-null, add jsonb columns and indexes:
```ruby
create_table :calculations do |t|
  t.references :user, null: true, foreign_key: true
  t.string :calculator, null: false
  t.jsonb  :inputs, null: false, default: {}
  t.jsonb  :result, null: false, default: {}
  t.datetime :deleted_at
  t.timestamps
end
add_index :calculations, :calculator
add_index :calculations, :deleted_at
```

- [ ] **Step 2: Generate the view migration**

```bash
bin/rails generate migration CreateCalculationLogsView
```
Its `up`/`down` (raw SQL — denormalizes username for reporting):
```ruby
def up
  execute <<~SQL
    CREATE VIEW calculation_logs AS
    SELECT c.id, c.calculator, c.inputs, c.result, c.user_id,
           u.username, c.deleted_at, c.created_at, c.updated_at
    FROM calculations c
    LEFT JOIN users u ON u.id = c.user_id;
  SQL
end

def down
  execute "DROP VIEW IF EXISTS calculation_logs;"
end
```

- [ ] **Step 3: Write the failing test**

`test/models/calculation_test.rb`:
```ruby
require "test_helper"

class CalculationTest < ActiveSupport::TestCase
  test "persists inputs and result as jsonb and may be anonymous" do
    calc = Calculation.create!(calculator: "percentage", inputs: { base: "50", rate: "20" }, result: { value: "10.0" })
    assert_nil calc.user
    assert_equal "20", calc.reload.inputs["rate"]
    assert_equal "10.0", calc.result["value"]
  end

  test "may belong to a user" do
    calc = Calculation.create!(calculator: "percentage", user: users(:alice), inputs: {}, result: {})
    assert_equal users(:alice), calc.user
  end

  test "is soft-deletable" do
    calc = calculations(:anon_pct)
    calc.discard
    assert_not_includes Calculation.kept, calc
  end

  test "calculation_logs view exposes the username" do
    row = ActiveRecord::Base.connection.select_one(
      "SELECT username FROM calculation_logs WHERE id = #{calculations(:alice_pct).id}"
    )
    assert_equal "alice", row["username"]
  end
end
```
`test/fixtures/calculations.yml`:
```yaml
anon_pct:
  calculator: percentage
  inputs: "{}"
  result: "{}"
alice_pct:
  calculator: percentage
  user: alice
  inputs: "{}"
  result: "{}"
```

- [ ] **Step 4: Run, watch fail**

Run: `bin/rails test test/models/calculation_test.rb`
Expected: FAIL — `Calculation` / table / view missing.

- [ ] **Step 5: Implement the model**

`app/models/calculation.rb`:
```ruby
class Calculation < ApplicationRecord
  include Discardable
  belongs_to :user, optional: true
end
```

- [ ] **Step 6: Run, watch pass**

Run: `bin/rails db:migrate && bin/rails test test/models/calculation_test.rb`
Expected: PASS (4 tests).

- [ ] **Step 7: Commit**

```bash
git add app/models/calculation.rb db/migrate db/structure.sql \
  test/models/calculation_test.rb test/fixtures/calculations.yml
git commit -m "$(printf 'feat: Calculation model and calculation_logs reporting view\n\nCo-Authored-By: Claude Fable 5 <noreply@anthropic.com>')"
```

---

## Task 4: CLI rake tasks (users + admins)

**Files:**
- Create: `lib/tasks/users.rake`, `lib/tasks/admins.rake`
- Test: `test/tasks/management_test.rb`

- [ ] **Step 1: Write the failing test**

`test/tasks/management_test.rb`:
```ruby
require "test_helper"
require "rake"

class ManagementTaskTest < ActiveSupport::TestCase
  setup do
    Whizwheel::Application.load_tasks if Rake::Task.tasks.empty?
    RoleType.find_or_create_by!(permalink: "ADMIN") { |rt| rt.display_name = "Admin" }
  end

  def run_task(name, *args)
    task = Rake::Task[name]
    task.reenable
    task.invoke(*args)
  end

  test "users:create makes a user with a password" do
    run_task("users:create", "carol", "secret123")
    assert User.authenticate_by(username: "carol", password: "secret123")
  end

  test "users:set_password changes the digest" do
    User.create!(username: "dave", password: "oldpass12")
    run_task("users:set_password", "dave", "newpass12")
    assert User.authenticate_by(username: "dave", password: "newpass12")
  end

  test "admins:grant then admins:revoke toggles admin?" do
    User.create!(username: "erin", password: "secret123")
    run_task("admins:grant", "erin")
    assert User.find_by(username: "erin").admin?
    run_task("admins:revoke", "erin")
    assert_not User.find_by(username: "erin").admin?
  end
end
```

- [ ] **Step 2: Run, watch fail**

Run: `bin/rails test test/tasks/management_test.rb`
Expected: FAIL — tasks not defined.

- [ ] **Step 3: Implement the rake tasks**

`lib/tasks/users.rake`:
```ruby
namespace :users do
  desc "Create a user: rake 'users:create[username,password]'"
  task :create, %i[username password] => :environment do |_t, args|
    user = User.create!(username: args[:username], password: args[:password])
    puts "Created user ##{user.id} (#{user.username})"
  end

  desc "Set a user's password: rake 'users:set_password[username,password]'"
  task :set_password, %i[username password] => :environment do |_t, args|
    user = User.find_by!(username: User.new(username: args[:username]).username)
    user.update!(password: args[:password])
    puts "Updated password for #{user.username}"
  end
end
```
`lib/tasks/admins.rake`:
```ruby
namespace :admins do
  desc "Grant ADMIN to a user: rake 'admins:grant[username]'"
  task :grant, %i[username] => :environment do |_t, args|
    user = User.find_by!(username: User.new(username: args[:username]).username)
    admin = RoleType.find_or_create_by!(permalink: "ADMIN") { |rt| rt.display_name = "Admin" }
    user.roles.kept.find_or_create_by!(role_type: admin)
    puts "#{user.username} is now an admin"
  end

  desc "Revoke ADMIN from a user: rake 'admins:revoke[username]'"
  task :revoke, %i[username] => :environment do |_t, args|
    user = User.find_by!(username: User.new(username: args[:username]).username)
    user.roles.kept.joins(:role_type).where(role_types: { permalink: "ADMIN" }).each(&:discard)
    puts "#{user.username} is no longer an admin"
  end
end
```

- [ ] **Step 4: Run, watch pass**

Run: `bin/rails test test/tasks/management_test.rb`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/tasks/users.rake lib/tasks/admins.rake test/tasks/management_test.rb
git commit -m "$(printf 'feat: CLI rake tasks for user and admin management\n\nCo-Authored-By: Claude Fable 5 <noreply@anthropic.com>')"
```

---

## Task 5: 100% coverage gate (SimpleCov) + CI

**Files:**
- Modify: `Gemfile`, `test/test_helper.rb`

- [ ] **Step 1: Add SimpleCov**

In `Gemfile`, inside the existing `group :test do` block, add:
```ruby
gem "simplecov", require: false
```
Run: `bundle install`

- [ ] **Step 2: Configure the gate — must be the FIRST lines of `test/test_helper.rb`**

Prepend to `test/test_helper.rb` (before `ENV["RAILS_ENV"] ...`):
```ruby
require "simplecov"
SimpleCov.start "rails" do
  enable_coverage :branch
  add_filter "/test/"
  add_filter "/config/"
  add_filter "/app/channels/"   # none yet; future-proofing
  minimum_coverage line: 100, branch: 100
end
```

- [ ] **Step 3: Run the full suite and confirm 100%**

Run: `bin/rails test`
Expected: all tests PASS **and** SimpleCov prints `Line Coverage: 100.0%` / `Branch Coverage: 100.0%` with no "below minimum" error.
If coverage is below 100%, SimpleCov lists the files + uncovered lines — **add focused tests for exactly those lines/branches**, then re-run. Do not lower the threshold.

- [ ] **Step 4: Confirm CI runs the gate**

The CI `test` job already runs `bin/rails db:test:prepare test`, which now loads SimpleCov via `test_helper.rb`. No workflow change needed. Verify locally that `bin/rails test` exits non-zero if coverage drops (sanity: temporarily delete a test, confirm failure, restore it).

- [ ] **Step 5: Commit**

```bash
git add Gemfile Gemfile.lock test/test_helper.rb
git commit -m "$(printf 'test: enforce 100%% line+branch coverage via SimpleCov\n\nCo-Authored-By: Claude Fable 5 <noreply@anthropic.com>')"
```

- [ ] **Step 6: Push and watch CI**

```bash
git push origin <branch>
```
Then dispatch `ci-monitor` (or `bin/ci-watch <branch> --poll`) and confirm all five jobs are green — `test` now includes the coverage gate, and `structure.sql` carries the full schema.

---

## Self-Review

**Spec coverage:**
- Discardable concern → Task 2 (defined), Task 2/3 (applied to Role, RoleType, Calculation), tested in `discardable_test.rb`. ✅
- Auth (username/password, no email/reset/signup) → Task 1. No `PasswordsController`/mailer/registration created. ✅
- RBAC (RoleType seeded ADMIN, Role, `User#admin?`) → Task 2 + `db/seeds.rb`. ✅
- Calculation (nullable user FK, slug, jsonb inputs/result, deleted_at) + `calculation_logs` view → Task 3. ✅
- First migration fills `structure.sql` + greens CI → Tasks 1–3 migrations (schema_format `:sql`), verified Task 5 Step 6. ✅
- CLI rake tasks → Task 4. ✅
- SimpleCov 100% in `test_helper` + CI → Task 5. ✅
- Calculator scaffolding excluded → not present anywhere. ✅

**Placeholder scan:** No TBD/TODO. `home_controller` + its view are an explicit, functional placeholder (noted as the frontend agent's to replace), not a plan placeholder.

**Type consistency:** `Discardable` methods (`discard`/`undiscard`/`discarded?`, `kept`/`discarded`) are identical across the concern, its tests, the rake tasks (`roles.kept`, `.discard`), and `User#admin?`. `User.authenticate_by(username:, password:)` matches the column and is used identically in the model test, integration test, controller, and rake tests. `permalink: "ADMIN"` is identical in the model, seeds, fixtures, and both rake tasks. Migration column names match every model/test/view reference.
