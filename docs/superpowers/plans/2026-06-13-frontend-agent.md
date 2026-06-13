# Frontend Agent + BLEND Design System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `frontend` agent and dogfood it by restyling the placeholder `home/index` + `sessions/new` pages into the first reference implementation of the BLEND design system, on a Tailwind toolchain.

**Architecture:** Mirror the backend's doc-driven model — `docs/DESIGN.md` (BLEND system, main-thread authored) is to the `frontend` agent what `ARCHITECTURE.md` is to the backend agent. The main thread does the one-time toolchain install + the conventions/agent docs; the `frontend` agent owns the design implementation (Tailwind `@theme` tokens, view chrome, restyled pages, tests). The login dogfood becomes the living template future pages copy.

**Tech Stack:** Rails 8.1, Propshaft, importmap, Hotwire (Turbo + minimal Stimulus), **Tailwind CSS v4 via `tailwindcss-rails`** (standalone binary — no Node), Minitest + SimpleCov (100% gate), Postgres.

**Execution model (hybrid):** Tasks 0–4 are **main-thread** (this session) — infra + docs, executed directly. Task 5 is **dispatched to the `frontend` agent** (read-and-adopt: a generic subagent pointed at `.claude/agents/frontend.md` + `CLAUDE.md`, since the new agent type isn't registered until a session reload). Tasks 6–7 are main-thread (verify + ship).

---

## File Structure

| Path | Responsibility | Owner |
|---|---|---|
| `Gemfile` | add `tailwindcss-rails` | main thread |
| `app/assets/tailwind/application.css` | Tailwind input + BLEND `@theme` tokens | agent (created by install, themed by agent) |
| `app/assets/builds/.keep` | keep dir; built CSS is gitignored | main thread |
| `Procfile.dev`, `bin/dev` | foreman: web + CSS watch | main thread |
| `.github/workflows/ci.yml` | build CSS before tests | main thread |
| `docs/DESIGN.md` | the BLEND design system (source of truth) | main thread |
| `.claude/agents/frontend.md` | the frontend agent definition | main thread |
| `CLAUDE.md` | "Starting the app" update + read-first/roster | main thread |
| `app/views/layouts/application.html.erb` | nav + footer + flash chrome | agent |
| `app/views/home/index.html.erb` | restyled, signed-in/out states | agent |
| `app/views/sessions/new.html.erb` | restyled login form | agent |
| `app/helpers/*` | any view helpers (100% covered) | agent |
| `test/integration/*` | render + state assertions | agent |

---

## Task 0: Branch

**Files:** none (git).

- [ ] **Step 1: Confirm clean tree on main**

Run: `git switch main && git pull && git status --short`
Expected: no output (clean), up to date.

- [ ] **Step 2: Create the feature branch**

Run: `git switch -c fix/7-frontend-agent`
Expected: `Switched to a new branch 'fix/7-frontend-agent'`

---

## Task 1: Install the Tailwind toolchain (main thread)

**Files:**
- Modify: `Gemfile` (add gem), `app/views/layouts/application.html.erb` (stylesheet link), `.gitignore`, `.github/workflows/ci.yml`, `bin/dev`
- Create: `app/assets/tailwind/application.css`, `Procfile.dev`, `app/assets/builds/.keep`

- [ ] **Step 1: Add the gem**

Add to `Gemfile` (near `propshaft`):
```ruby
# Tailwind CSS, bundled standalone binary (no Node) [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"
```
Run: `bundle install`
Expected: bundles `tailwindcss-rails` (and `tailwindcss-ruby`).

- [ ] **Step 2: Run the installer**

Run: `bin/rails tailwindcss:install`
Expected: creates `app/assets/tailwind/application.css` (with `@import "tailwindcss";`), `app/assets/builds/`, adds a `tailwind` stylesheet link to the layout, and may create/overwrite `Procfile.dev` + `bin/dev`. Note what it generated.

- [ ] **Step 3: Pin `bin/dev` to foreman (known-good)**

Overwrite `bin/dev` with:
```bash
#!/usr/bin/env bash

if ! gem list foreman -i --silent; then
  echo "Installing foreman..."
  gem install foreman
fi

exec foreman start -f Procfile.dev "$@"
```
Run: `chmod +x bin/dev`

- [ ] **Step 4: Pin `Procfile.dev`**

Ensure `Procfile.dev` contains exactly:
```
web: env RUBY_DEBUG_OPEN=true bin/rails server
css: bin/rails tailwindcss:watch
```

- [ ] **Step 5: Confirm the layout links the built CSS**

`app/views/layouts/application.html.erb` must include (the installer usually adds it; verify) inside `<head>`, alongside the existing `:app` link:
```erb
<%= stylesheet_link_tag "tailwind", "data-turbo-track": "reload" %>
```

- [ ] **Step 6: Gitignore the built CSS, keep the dir**

Add to `.gitignore`:
```
# Tailwind build output (generated)
/app/assets/builds/*
!/app/assets/builds/.keep
```
Run: `touch app/assets/builds/.keep`

- [ ] **Step 7: Build the CSS and verify it lands**

Run: `bin/rails tailwindcss:build`
Expected: writes `app/assets/builds/tailwind.css` (non-empty).

- [ ] **Step 8: Verify the existing suite still passes (with the asset present)**

Run: `bin/rails db:test:prepare && bin/rails tailwindcss:build && bin/rails test`
Expected: all green, coverage 100% (the layout now links `tailwind.css`; the build makes Propshaft resolve it).

- [ ] **Step 9: Make CI build CSS before tests**

In `.github/workflows/ci.yml`, in BOTH the `test` and `system-test` jobs, add a build step immediately before the run step:
```yaml
      - name: Build CSS
        run: bin/rails tailwindcss:build
```
(Place it after "Set up Ruby"/"Install packages" and before "Run tests" / "Run System Tests". This guarantees `tailwind.css` exists when the layout renders, independent of test:prepare hooks.)

- [ ] **Step 10: Lint + security gates locally**

Run: `bin/rubocop && bin/brakeman --no-pager`
Expected: no offenses, no warnings. (Fix any rubocop nits in generated `bin/dev`/config.)

- [ ] **Step 11: Commit**

```bash
git add Gemfile Gemfile.lock app/assets/tailwind app/assets/builds/.keep \
        Procfile.dev bin/dev .gitignore .github/workflows/ci.yml \
        app/views/layouts/application.html.erb
git commit -m "build: add Tailwind CSS toolchain (tailwindcss-rails)

Standalone binary (no Node). Adds Procfile.dev + foreman bin/dev (the
CSS watcher), gitignores the generated build, and builds CSS before
tests in CI so the layout's tailwind link resolves under Propshaft.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Task 2: Author `docs/DESIGN.md` (the BLEND system)

**Files:** Create `docs/DESIGN.md`.

This is the design source of truth, sibling to `ARCHITECTURE.md`. Author it from the approved spec (`docs/superpowers/specs/2026-06-13-frontend-agent-design.md §4`). It MUST contain, concretely:

- [ ] **Step 1: Write `docs/DESIGN.md`** with these sections and exact values:

**Status/intro:** living doc; the single source of truth for how whizwheel *looks*; every UI build reads it; sibling to `ARCHITECTURE.md`. The aesthetic name is **BLEND** (warm + sharpened + a touch of green).

**Color tokens** (table — token → hex → use), exactly:
| Token | Value | Use |
|---|---|---|
| `bg` | `#fdf8f3` | page background |
| `surface` | `#ffffff` | cards/panels |
| `ink` | `#241d18` | primary text/hard numbers |
| `muted` | `#6f6155` | body/lede |
| `label` | `#8a7768` | field labels |
| `faint` | `#a08a7c` | table headers/de-emphasis |
| `primary` | `#ef6c4d` | primary actions, hero accent rule (coral) |
| `accent` | `#2f9e6f` | brand dot, active tab, largest chart slice, positive/eyebrow (green) |
| `amber` | `#ffb703` | tertiary chart slice |
| `border` | `#f3ebe2` | card borders |
| `border-input` | `#ece1d6` | input borders (focus → `accent`) |
| `rule` | `#efe4d8` | table rules |

State the rule: **green is a touch, coral leads chrome/actions.** Green appears on: brand dot (halo `rgba(47,158,111,.16)`), active tab, donut's largest slice (principal & interest), eyebrow labels, select positive stats.

**Typography:** family `"Inter", "Helvetica Neue", system-ui, sans-serif`; headlines weight 800, tracking `-0.035em`, sweeping (page title ≈ 40px, hero result ≈ 54px @ `-0.04em`); **`tabular-nums` wherever numbers matter**; eyebrow 11px `.12em` uppercase green; labels 12px bold `#8a7768`; lede 15px `#6f6155`.

**Shape/spacing:** radii — cards 18px, inputs 11–13px, buttons 13px, pills/tabs 999px; card shadow `0 10px 34px rgba(150,110,80,.12)` + 1px `border`; generous whitespace; responsive grid (form column + results panel desktop → stacked mobile).

**Component vocabulary:** nav (wordmark + green dot), footer, flash (success/alert), inputs (with `$`/`%`/unit affixes), primary button, tab pills, card, hero-result (white card, 5px coral left rule, big tabular number), stat grid (3-up), charts (donut via `conic-gradient`; thin stacked bar), data table (thin rules, right-aligned tabular nums, hard total row).

**Tailwind mapping:** tokens are declared in `app/assets/tailwind/application.css` under `@theme` (Tailwind v4), e.g. `--color-primary: #ef6c4d;` → utility `bg-primary`/`text-primary`; `--font-sans` for the family. Components are expressed as Tailwind utility classes in ERB; extract shared partials/`@apply` only when a pattern repeats ≥3×.

**Accessibility & responsive:** semantic HTML; `<label>` per input; visible focus (→ green); WCAG AA contrast (verify coral/green on cream); mobile-first; two-column collapses to one; tables scroll/reflow.

**The seam:** the UI renders the JSON envelope from `ARCHITECTURE.md §4`; it codes against that and these tokens, nothing else.

- [ ] **Step 2: Commit**

```bash
git add docs/DESIGN.md
git commit -m "docs: DESIGN.md — the BLEND design system (source of truth)

Color tokens, type scale (sharp grotesk + tabular nums), component
vocabulary, Tailwind @theme mapping, a11y/responsive rules. Sibling to
ARCHITECTURE.md; read by the frontend agent before any UI work.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Task 3: Update `CLAUDE.md` (conventions now true)

**Files:** Modify `CLAUDE.md`.

These edits land in the feature PR (not directly on main) because they describe code that changes in this same PR (the Tailwind build step + DESIGN.md).

- [ ] **Step 1: Rewrite the "Starting the app" section** to reflect the build step.

Replace the importmap/propshaft "no Procfile, no foreman" claims with: `bin/rails db:prepare` (unchanged) then **`bin/dev`** now runs **foreman** from `Procfile.dev` — `web` (the Rails server) + `css` (`tailwindcss:watch`, the Tailwind build). Note: Tailwind uses a standalone binary (no Node); the built `app/assets/builds/tailwind.css` is gitignored and produced by the watcher locally / `tailwindcss:build` in CI. Serves on http://localhost:3000.

- [ ] **Step 2: Add `DESIGN.md` to "Read these first"** with a one-line description: *the design system every UI build ingests (BLEND tokens, type, components).*

- [ ] **Step 3: Update "The agents" roster** — change `frontend *(not built yet)*` to describe the built agent: owns the UI (`app/views`, `app/helpers`, `app/assets`, Stimulus), reads `DESIGN.md`, codes against the JSON envelope. Add a line that every UI build agent ingests `DESIGN.md` (alongside `ARCHITECTURE.md` + `PRODUCT.md`).

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: CLAUDE.md — Tailwind startup (foreman) + DESIGN.md/frontend agent

Starting-the-app now reflects bin/dev via foreman (web + css watcher);
adds DESIGN.md to read-first and the frontend agent to the roster.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Task 4: Author `.claude/agents/frontend.md`

**Files:** Create `.claude/agents/frontend.md`.

- [ ] **Step 1: Write the agent definition** with this structure (modeled on `pm.md`):

**Frontmatter:**
```yaml
---
name: frontend
description: Use for whizwheel UI work — building and restyling views, the layout chrome, helpers, Tailwind theme/tokens, and Stimulus controllers, per docs/DESIGN.md. Owns app/views, app/helpers, app/assets, app/javascript/controllers; codes against the JSON envelope (ARCHITECTURE.md §4). Never writes calculator math, models, controller business logic, migrations, or routes.
tools: Read, Write, Edit, Bash
model: opus
---
```

**Body — required sections:**
- **Launch protocol (Step 0, every invocation):** read `CLAUDE.md`, then `docs/ARCHITECTURE.md`, `docs/PRODUCT.md`, and **`docs/DESIGN.md`** in full before any work. (Mirror pm's no-shortcuts ingestion, scoped to these four.)
- **Role:** you build whizwheel's UI to the BLEND system — distinctive, usable, genuinely good (PRODUCT.md). You implement `DESIGN.md`; you do not invent the visual system.
- **Owns / hard boundary (never violate):** writes only `app/views/`, `app/helpers/`, `app/assets/`, `app/javascript/controllers/`. **Never** touches `app/calculators/` (math), models, controller business logic, migrations, `config/routes.rb`, or backend gems. If a task needs backend work, **stop and say so**. You may read anything.
- **The seam:** code against the JSON envelope (`ARCHITECTURE.md §4`) + `DESIGN.md` tokens — nothing else.
- **Interaction model:** Hotwire/Turbo + **minimal Stimulus**, progressive enhancement; consistent with all-server-side + importmap. No heavy client frameworks.
- **Styling:** Tailwind utilities in ERB; tokens live in `app/assets/tailwind/application.css` `@theme`; extract partials/`@apply` only when a pattern repeats ≥3×. Always run `bin/rails tailwindcss:build` before running tests/serving.
- **Quality bar:** keep the suite green and **coverage 100%** (any Ruby helper you add is covered); add **integration tests** asserting each page renders + its key states; **conform to `DESIGN.md`**; expect **human visual review**. (System tests reserved for interactive Stimulus.)
- **a11y:** semantic HTML, labels, visible focus, AA contrast — per `DESIGN.md`.
- **Git discipline:** path-scoped staging of UI paths only; conventional `feat(ui):` / `style:` messages; end bodies with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`; branch/PR per `CLAUDE.md`; never `git add -A`.
- **When unsure:** ask one short question rather than guess; never fabricate.

- [ ] **Step 2: Commit**

```bash
git add .claude/agents/frontend.md
git commit -m "feat(agents): add the frontend agent (BLEND, reads DESIGN.md)

Builds whizwheel's UI to the BLEND design system; owns views/helpers/
assets/Stimulus; hard boundary against math/models/migrations; codes
against the JSON envelope. Read-and-adopt until registered as a type.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Task 5: Dogfood — dispatch the frontend agent to restyle the pages

**Files (the agent will touch):**
- Modify: `app/views/layouts/application.html.erb`, `app/views/home/index.html.erb`, `app/views/sessions/new.html.erb`, `app/assets/tailwind/application.css`
- Create: `app/helpers/*` (if needed), `test/integration/home_test.rb`, `test/integration/sessions_styling_test.rb` (or extend existing auth tests)

**This task is dispatched**, not executed inline. Dispatch a subagent (read-and-adopt: instruct it to read `.claude/agents/frontend.md` + `CLAUDE.md` first and operate as the `frontend` agent). Give it this brief:

> Operate as the `frontend` agent (read `.claude/agents/frontend.md` + `CLAUDE.md` + `docs/DESIGN.md` first). Implement the first reference implementation of the BLEND design system on the existing pages. Deliverables:
> 1. **`@theme` tokens** in `app/assets/tailwind/application.css` — all `DESIGN.md` color tokens (`--color-bg`, `--color-surface`, `--color-ink`, `--color-muted`, `--color-label`, `--color-faint`, `--color-primary`, `--color-accent`, `--color-amber`, `--color-border`, `--color-border-input`, `--color-rule`) and `--font-sans: "Inter","Helvetica Neue",system-ui,sans-serif;`. Set the page `bg`/`ink`/font defaults on `body`.
> 2. **Layout chrome** (`application.html.erb`): a top nav (whizwheel wordmark with the green dot, halo per DESIGN.md; links: Calculators, History, and Sign in / "Signed in as X" + Sign out based on `current_user`), a simple footer, and **flash messages** styled to BLEND (success vs alert). Keep `csrf/csp` tags, both stylesheet links, and `javascript_importmap_tags`.
> 3. **`home/index.html.erb`**: a BLEND landing — signed-out shows a welcome + prominent "Sign in"; signed-in shows "Signed in as {username}" + Sign out — using DESIGN tokens/components, not raw HTML.
> 4. **`sessions/new.html.erb`**: the login form as a BLEND card (labeled username/password inputs, coral primary "Sign in" button), with the failed-login **flash alert** rendering (the Chapter 14 fix must remain visibly working).
> 5. **Tests:** integration tests asserting: signed-out home renders the sign-in affordance; signed-in home renders the username + sign-out; the login page renders the form + labels; a failed login renders the "Invalid username or password" alert. Keep ALL existing tests green and **coverage at 100%** (cover any helper you add).
> 6. Run `bin/rails tailwindcss:build` then `bin/rails db:test:prepare && bin/rails test`; run `bin/rubocop`. Everything green before reporting done.
> Hard rule: touch only `app/views`, `app/helpers`, `app/assets`, `app/javascript`, `test/`. Do NOT touch models, controllers' logic, routes, migrations, or `app/calculators`.

- [ ] **Step 1: Dispatch the agent** with the brief above.
- [ ] **Step 2: Independent spec-compliance review** — verify (don't trust the report): read the diff; confirm only allowed paths changed; run `bin/rails tailwindcss:build && bin/rails test` (green, 100%); run `bin/rubocop` (clean); confirm DESIGN tokens are actually used (no hard-coded hexes in ERB) and the failed-login alert renders.
- [ ] **Step 3: Code-quality review** of the views (semantics, a11y labels, DESIGN conformance, no duplication). Apply judgment on findings; fix real ones via the agent.
- [ ] **Step 4: Commit** (the agent commits its own work; ensure path-scoped, conventional message, Fable 5 trailer).

---

## Task 6: Verify live + visual review

**Files:** none (runtime verification).

- [ ] **Step 1: Prepare DB + a user**

Run: `bin/rails db:prepare && bin/rails "users:create[demo,password123]" && bin/rails "admins:grant[demo]"`
Expected: ADMIN seeded, user `demo` created + admin.

- [ ] **Step 2: Start the app**

Run: `bin/dev` (foreman: web + css). Wait for the server on http://localhost:3000.

- [ ] **Step 3: Capture/inspect the three states**

Anonymous home, login page, signed-in home, and a failed login (wrong password → BLEND alert). Confirm BLEND is visibly applied (cream bg, coral button, green dot, sharp type). Present screenshots to the user for the "does this meet your expectations?" check (Chapter 18 precedent).

- [ ] **Step 4: Stop the server** once reviewed.

---

## Task 7: Ship (Issue #7)

**Files:** none (git/GitHub).

- [ ] **Step 1: Push the branch**

Run: `git push -u origin fix/7-frontend-agent`

- [ ] **Step 2: Open the PR**

Run `gh pr create` with `Closes #7` in the body, summarizing: the frontend agent, DESIGN.md/BLEND, the Tailwind toolchain trade-off, and the restyled pages. End the body with the Claude Code footer.

- [ ] **Step 3: Watch CI**

Dispatch `ci-monitor` (`--pr <n>`). Expect all jobs green (scan_ruby, scan_js, lint, test, system-test). Fix any failure at its root (likely a missing CSS build → confirm Task 1 Step 9 landed).

- [ ] **Step 4: Await explicit human merge** — never auto-merge. On say-so: `gh pr merge <pr> --merge`, then delete the remote+local branch, `git switch main && git pull`.

- [ ] **Step 5: Journal** — fire the historian (background mid-flow, or to completion at session end) to record the build, the dogfood result, and whether the frontend agent needed correction (the convergence data point).

---

## Self-Review (done at authoring)

- **Spec coverage:** §3 decisions → Tasks 1 (Tailwind), 2 (DESIGN.md), 4 (agent); §4 BLEND system → Task 2 (verbatim tokens) + Task 5 (applied); §5 agent shape → Task 4; §6 dogfood scope + install split → Tasks 1 (main thread) vs 5 (agent); §6 out-of-scope (calculator/history/admin) → explicitly excluded. ✅
- **Placeholder scan:** no TBD/TODO; commands and file contents are concrete; the one delegated task (5) carries a complete dispatch brief. ✅
- **Consistency:** token names match between Task 2 and Task 5; `tailwindcss:build` ordering before tests is consistent (Task 1 Step 8/9, Task 5 Step 6, CI). The CSS-build-before-render requirement (Propshaft) is handled in local runs and both CI jobs. ✅
- **Deviation from spec (noted):** spec §5 said "system tests"; plan uses **integration tests** for these static pages (cheaper, no browser; foundation precedent), reserving system tests for interactive Stimulus. ✅
