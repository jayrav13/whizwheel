## Chapter 6 — The product takes shape (2026-06-13)

Designing `ARCHITECTURE.md` surfaced the real product, decision by decision:

- **Calc objects = ActiveModel POROs (option A).** The user asked plainly, *"What is a PORO?"*, then chose A: plain Ruby objects with `ActiveModel` for validation + typed `:decimal` (BigDecimal) attributes, **no database** — which is what makes the math layer purely, exhaustively testable.
- **Persistence, deliberately layered.** The user: *"I'd like users to be able to log into the website and to have all calculations tied to a user … This might seem like a privacy nightmare, but remember this is an experiment, not a product that I'm looking to ship viably."* Then a sharp layering refinement: a calculator *"can instantiate a DB record that hasn't been created yet and return it … the controller should be the one that actually creates the model"* — so the response is decoupled from persistence, and recording can later move to a background job with no contract change.
- **Auth:** *"We collect username and password from a user, no emails for now"* — adapted Rails 8 auth, no email, no password reset, no sign-up; users via CLI.
- **RBAC:** `RoleType`/`Role` with a seeded `ADMIN`; revoking = soft-deleting the `Role`. Then a simplification: *"No portion of this app handles user creation or role creation"* — roles are DB/CLI-managed; the ADMIN role only *gates* a site-wide stats view.
- **Soft-delete** became a cross-cutting convention (`Discardable`); per-user views hide discarded rows, site-wide usage counts all.
- **Naming/ontology:** the user asked, *"should it be called app/calculators/* instead of app/calculations/*"* — yes, clarifying the ontology: a **calculator** is the type/code; a **calculation** is one run (a DB row); `calculation_logs` is a reporting view. Calculators are **code, append-only** — *"discourage deleting calculators … we'll lose some comparability."*

**Agent-driven?** ✅ All of it landed in `ARCHITECTURE.md`, the doc agents read — not in code.

---
