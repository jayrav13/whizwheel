# whizwheel — Product Vision

**Status:** Living document, stewarded by the PM agent (the PM keeps it current; it does not decide direction — that's the user's). This is the **canonical statement of what whizwheel is, for users.** Its sibling is [`ARCHITECTURE.md`](ARCHITECTURE.md) — *how* we build; this is *what* we build.

> whizwheel is also an experiment in agent-driven development. That meta-purpose lives in the PM spec under `docs/superpowers/specs/`. **This doc is about the product itself** — written as if it were a real thing people use.

---

## What it is

A reimagining of [calculator.net](https://www.calculator.net): a broad library of calculators with a beautiful, fast UI. All math runs **server-side** and is verifiable to the decimal against calculator.net.

## Who it's for & the core experience

- **Anyone** can use any calculator — no login required. Inputs in, answer out.
- **Signed-in users** get a personal **history** of their calculations and **usage stats**, and can **soft-delete** any item or clear all of it (their view; never truly destroyed).
- **Admins** get a **site-wide usage dashboard** — how much each calculator is used across everyone.

## Feature areas

1. **Calculators** — reproductions of calculator.net's catalog (**191 catalogued** in `docs/INVENTORY.md`), each a clean page: typed inputs → computed result. Built one at a time, increasing in complexity.
2. **Accounts** — `username` + password login. **No email, no self-signup, no password-reset-by-email.** Users are provisioned via CLI (`bin/rails "users:create[...]"`).
3. **Personal history & stats** — per-user calculation history and usage statistics; user-controlled soft-deletion (item or all).
4. **Admin & site-wide stats** — an ADMIN-gated dashboard of overall usage. Site-wide totals count *all* invocations (a user hiding their own history doesn't erode them).
5. **Roles** — `RoleType`/`Role` with an `ADMIN` type. Granted/revoked via CLI for now; no management UI yet.

## Product principles

- **Usage-tracking is deliberate, and this is an experiment, not a shippable product.** We tie calculations to users on purpose; soft-delete gives users control over their *own* view while the site retains usage truth.
- **Correctness is non-negotiable** — calculators match calculator.net to the decimal.
- **The UI should be genuinely good** — distinctive and usable, not generic. (The frontend agent's charge.)

## Status

Foundation-of-the-foundation is in place: project tracking (PM agent), the calculator catalog, and engineering conventions (`ARCHITECTURE.md`). **No user-facing features are built yet.**

## Roadmap (current decomposition)

1. **App foundation** — auth, RBAC, `Calculation` model + view, soft-delete, CLI tasks, first migration (→ green CI).
2. **Backend agent** → **first calculator (Percentage)** — proves the agent-driven build loop.
3. **Personal history & stats page.**
4. **Admin site-wide stats.**
5. **Broaden calculator coverage**, iteration by iteration, up the complexity gradient.

## Where things live (map)

| Need | Look in |
|---|---|
| How we build (conventions) | `docs/ARCHITECTURE.md` |
| Calculator catalog | `docs/INVENTORY.md` |
| The experiment & tracking | `docs/superpowers/specs/` + the PM agent |
| Open work | GitHub Issues (`engineering` / `agents`) |
| Per-feature designs | `docs/superpowers/specs/` |
