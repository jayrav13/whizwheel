# Frontend agent + the BLEND design system — design

**Status:** Approved design (brainstorm complete) → implementation plan next.
**Date:** 2026-06-13
**Issue:** #7 (Build the frontend agent)
**Siblings:** `docs/ARCHITECTURE.md` (how we build), `docs/PRODUCT.md` (what we build), `CLAUDE.md` (the shared contract).

---

## 1. Goal

Build the **frontend agent** (`.claude/agents/frontend.md`) — the agent that encodes whizwheel's UI taste and discipline — and **dogfood it immediately** by restyling the currently-bare placeholder pages (`home/index`, `sessions/new`) into the first **reference implementation** of the design system. This is the symmetric construction to the backend agent, and the first real test of whether *visual* taste (not just objective math) can be carried by an agent definition + a conventions doc.

## 2. The parallel (why this mirrors the backend)

Chapter 5's load-bearing insight: **the vision lives in a doc the agent reads, not baked into the agent.**

| Backend | Frontend (this work) |
|---|---|
| `docs/ARCHITECTURE.md` — how to build | **`docs/DESIGN.md`** — the BLEND design system |
| `backend` agent reads it before coding | **`frontend` agent reads it before coding** |
| Percentage = first reference calculator | **login/home pages = first reference implementation** |

So three artifacts are produced: **`docs/DESIGN.md`**, **`.claude/agents/frontend.md`**, and **the dogfood build**.

## 3. Decisions made during the brainstorm

1. **Aesthetic = BLEND.** Reached via the visual companion: shown four directions (Swiss/editorial, Technical/instrument, Warm/approachable, Bold/distinctive), the user narrowed to **A (Swiss)** + **C (Warm)**, then asked for a blend stress-tested on a complex mortgage page. The settled **BLEND** = C's warmth, soft cards and donut chart, **sharpened** with a crisp grotesk (tight, sweeping headlines + tabular numerals), A's table/numeric discipline, and **a touch of green** threaded into the warm palette. Coral remains the primary action color.
2. **CSS = Tailwind** (`tailwindcss-rails`). An informed override of the recommended plain-CSS-tokens path. **Consequence (a deliberate trade):** this reverses the celebrated *no-build-step* property — it adds a standalone Tailwind build (no Node required), a `Procfile.dev`, and rewires `bin/dev` to run **foreman** (web + CSS watcher). CLAUDE.md's "Starting the app" section must be updated accordingly. Design tokens live in the CSS via Tailwind v4's `@theme`.
3. **Design source of truth = `docs/DESIGN.md`**, authored by the **main thread** (this session), exactly as `ARCHITECTURE.md` was — codifying the user's approved taste. The frontend agent *reads and implements* it; it does not invent the system.
4. **Install lane split.** The **main thread** does the one-time toolchain install + the conventions/agent docs (like the CI/infra precedent). The **frontend agent** owns the design implementation: the `@theme` BLEND tokens, the views/chrome, and the tests.

## 4. The BLEND design system (spec for `docs/DESIGN.md`)

### 4.1 Color tokens
| Token | Value | Use |
|---|---|---|
| `bg` | `#fdf8f3` | page background (warm cream) |
| `surface` | `#ffffff` | cards, panels |
| `ink` | `#241d18` | primary text, hard numbers |
| `muted` | `#6f6155` | body/lede text |
| `label` | `#8a7768` | field labels |
| `faint` | `#a08a7c` | table headers, de-emphasis |
| **`primary` (coral)** | `#ef6c4d` | primary actions (buttons), hero accent rule |
| **`accent` (green)** | `#2f9e6f` | brand dot, active tab, largest chart slice, positive/eyebrow |
| `amber` | `#ffb703` | tertiary chart slice |
| `border` | `#f3ebe2` | card borders |
| `border-input` | `#ece1d6` | input borders (focus → `accent`) |
| `rule` | `#efe4d8` | table rules |

Green is a **touch**, not dominant: brand dot (with soft halo `rgba(47,158,111,.16)`), active tab, the donut's largest slice (principal & interest), eyebrow labels, and select positive stats. Coral leads chrome/actions.

### 4.2 Typography
- **Family:** sharp grotesk — `"Inter", "Helvetica Neue", system-ui, sans-serif`.
- **Headlines:** weight 800, tight tracking `-0.035em`, large and "sweeping" (page title ≈ 40px; hero result ≈ 54px at `-0.04em`).
- **Numerals:** `font-variant-numeric: tabular-nums` everywhere numbers matter (hero, chart amounts, schedules) so columns align (A's discipline).
- **Eyebrow:** 11px, `.12em` uppercase, green. **Labels:** 12px bold, `#8a7768`. **Lede:** 15px `#6f6155`.

### 4.3 Spacing / shape
- Radii: cards 18px, inputs 11–13px, buttons 13px, pills/tabs 999px.
- Card shadow: `0 10px 34px rgba(150,110,80,.12)`; 1px `border` outline.
- Generous whitespace; 12-col-ish responsive grid (form column + results panel on desktop, stacked on mobile).

### 4.4 Component vocabulary (the reference library)
Nav (wordmark + green dot), footer, flash messages (success/alert), inputs (with `$`/`%`/unit affixes), primary button, secondary/tab pills, **card**, **hero-result** (white card, 5px coral left rule, big tabular number), **stat grid** (3-up), **charts** (donut via `conic-gradient`; thin stacked bar), **data table** (thin rules, right-aligned tabular nums, hard total row), tabbed views.

### 4.5 Accessibility & responsive (requirements)
- Semantic HTML, `<label>` for every input, visible focus states (focus → green), WCAG AA contrast (verify coral/green on cream).
- Mobile-first; the desktop two-column collapses to a single column; tables scroll or reflow.

## 5. The frontend agent (spec for `.claude/agents/frontend.md`)

- **Frontmatter:** `name: frontend`, `tools: Read, Write, Edit, Bash` (+ as needed), `model: opus` (parity with the reasoning agents; revisit).
- **Launch protocol (Step 0):** read `CLAUDE.md`, `docs/ARCHITECTURE.md`, `docs/PRODUCT.md`, **`docs/DESIGN.md`** before any work — mirrors the pm protocol.
- **Owns:** `app/views/`, `app/helpers/`, `app/assets/` (Tailwind config + tokens), `app/javascript/controllers/` (Stimulus).
- **Codes against:** the **JSON envelope** (`ARCHITECTURE.md §4`) and the **DESIGN system** — nothing else.
- **Hard boundary (never violate):** never touches `app/calculators/` (math), models, controller business logic, migrations, routes, or backend gems. If a task needs backend work, stop and say so. (Modeled on pm's hard write boundary.)
- **Interaction model:** Hotwire/Turbo + **minimal Stimulus**, progressive enhancement — consistent with the all-server-side, importmap ethos. (How a calculator form submits to the JSON endpoint is settled jointly with the backend agent / first calculator; the login dogfood is a plain server-rendered POST and is unaffected.)
- **Quality bar:** **system tests (Capybara)** for render + key states; **100% coverage on any Ruby helpers** (the existing gate already enforces this); **conformance to DESIGN.md**; **human visual review** (screenshots, per Chapter 18). ERB itself is not coverage-counted.
- **Process:** brainstorm → spec → plan → build, per issue. Branch/PR/commit per `CLAUDE.md`.

### The honest asymmetry (an experiment data point to record)
The backend gets an **objective** gate (100% coverage + reference values to the decimal). The frontend cannot be gated that way — its bar is system tests + design-system conformance + **human visual judgment**. Whether visual taste *converges* through agent iteration the way math correctness does is the open question this agent exists to answer.

## 6. The dogfood build (scope of this effort)

**In scope** — the UI foundation + the two existing pages as the reference implementation:
- **(Main thread)** Tailwind install: `tailwindcss-rails` in the Gemfile, `bin/rails tailwindcss:install`, the resulting `Procfile.dev` + `bin/dev` rewrite; update CLAUDE.md "Starting the app" and add `DESIGN.md` to the read-first lists; write `docs/DESIGN.md` and `.claude/agents/frontend.md`.
- **(Frontend agent)** the BLEND `@theme` tokens; the shared **layout chrome** (nav with wordmark + green dot, footer, styled flash incl. the "Invalid username or password" alert from Chapter 14); restyle **`home/index`** (signed-in/out states) and **`sessions/new`** (login form) to BLEND; **system tests** + a visual pass.

**Out of scope** (later frontend-agent jobs, per issue #7): calculator UI, per-user history/stats, admin site-wide dashboard — they require backend/data that doesn't exist yet.

## 7. Forward items (noted, not solved here)
- **Calculator submit mechanism** (HTML page ↔ JSON envelope) — settled with the backend agent / first calculator.
- **Charts** beyond CSS (`conic-gradient` donut, flex bar) — revisit if a calculator needs richer viz.
- **Agent model** (`opus` vs `sonnet`) — revisit after observing cost/quality.

## 8. Work breakdown (full plan via writing-plans)
1. **Main thread:** Tailwind install + `bin/dev`/Procfile + CLAUDE.md "Starting the app" update.
2. **Main thread:** author `docs/DESIGN.md` (the system above) + add to read-first lists.
3. **Main thread:** author `.claude/agents/frontend.md`.
4. **Frontend agent (dogfood):** `@theme` tokens + layout chrome + restyle `home/index` & `sessions/new` + system tests.
5. **Verify:** run app live (per CLAUDE.md "Starting the app"), screenshot review, CI green.
6. **Ship:** Issue #7 → branch → PR (`Closes #7`) → ci-monitor → human merge → cleanup → journal.
