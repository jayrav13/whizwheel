## Chapter 51 — Iteration 0002 opens as a single-variable bisect: the first regeneration sweep is dispatched (2026-06-13)

With both docs PRs cleared (#37 closed iteration 0001; #38 landed the spacing scale; both CI-green and 8/8 visually unchanged — the Percentage shots now correctly part of `main`'s baseline), the user said *"go for all."* Both merged, `main` at **1e18ce2** (spacing scale live), iteration 0001 closed.

Then the experiment ran its **first real regeneration sweep**. The assistant kicked **two agents in parallel** (PM touches `docs/logs`, FE touches `app/views` — no collision): the **PM** opening **iteration 0002** (pinned `1e18ce2`, tag `iteration-0002`, INDEX row, README noting the agent delta is the DESIGN.md spacing scale and that this is a *frontend-only* regen — the backend math is unchanged so it carries no signal; **PR #39**, docs-only), and the **FE agent regenerating the Percentage page from spec** — *explicitly not reading the old page*, rebuilding fresh from issue #31's spec + the new `DESIGN.md`.

The assistant framed the measurement precisely, and the user gave it the word that named it:

> "This is an awesome case study and your framing here is perfect, we'll bisect which part of the agent to work on next"

The assistant agreed *"bisect"* was exactly right *"because we changed precisely one variable: the DESIGN.md scale, holding `frontend.md`'s self-review constant."* So the regen outcome isolates cause: **pills come out roomy → DESIGN.md was the missing piece (the self-review bar was adequate, it just had nothing concrete to measure against — lever found); pills still cramped → the binding constraint is the agent's *eye* (the rubber-stamping self-review) → iteration 0003 targets `frontend.md`.** It held one honest caveat: *"agent output is stochastic, so a single regen is a strong signal, not proof"* — a couple more regens if the result is ambiguous. **The regeneration outcome is not yet known** — the FE agent was still building when the window closed; this is journaled at "dispatched + awaiting measurement."

**The operating principle — "stay ahead of the airplane."** When the assistant reported it was waiting on the regen, the user prompted a `ci-monitor` for the already-cleared #39, then named the broader principle as something worth remembering:

> "as they say in aviation - 'always stay ahead of the airplane' :D - if there's something we can be backgrounding that we're unblocked for, always try to catch and kick - this is the idea of agentic work I love and would like to hone in on"

The assistant saved it to memory as an operating principle and immediately practiced it — *"to practice what I just saved"* — by kicking the **historian** (which it had been holding under the PR-first rule) in a journal worktree to capture this very arc, PR-compliant. It also flagged an honest wrinkle the catch surfaced: routing the historian through a worktree + main-thread-PR is *slightly ceremonial* now that PR-first broke its old "just commit" model — a small future `historian.md` refinement (*"mid-session: commit on a branch and open a docs PR"*), noted agent-first, not done in the moment.

**Agent-driven? ✅** Iteration 0002 is the experiment's machinery doing exactly what it was built for: a *single-variable change* to an agent's reference doc, then a *from-spec regeneration* to measure whether that change alone moves the output — a controlled bisect of which agent layer is the lever. Whether the guidance worked is the open question the next session answers; the *setup* is the cleanest the experiment has produced. The "stay ahead of the airplane" principle was banked as durable operating guidance and acted on within the same turn.

---
