## Chapter 52 — The payoff: the regeneration came back roomy, and the bisect named the lever (2026-06-14)

This is the chapter Chapter 51 was holding its breath for. The single-variable bisect set up in iteration 0002 — change *only* the `DESIGN.md` spacing scale, regenerate the Percentage page from spec with `frontend.md`'s self-review held constant — finally returned a result, and the result was the one the whole experiment was built to be able to produce.

While the regeneration was still building, the user moved a piece of process up into the repo (Chapter 53), and the assistant kept the board moving rather than idling. Then the FE agent finished, and the assistant flagged the moment plainly:

> "Big moment — the **FE regeneration is done: PR #41**, and the agent reports the pills 'genuinely breathe now.' That's the measurement, pending my own eyes."

The "pending my own eyes" mattered: the agent's self-report is not the measurement; the measurement is the screenshot, viewed against the iteration-0001 baseline. The assistant pulled #41's four Percentage shots via `bin/ci-screenshots`, found all four `CHANGED` (the regen rewrote the page), and viewed them — *"the pills, the heart of the measurement."* It read the change-mode view first, then delivered the verdict:

> "The change-mode view confirms it. **This is the measurement — and the result is a clean win.**"

The comparison it drew, baseline vs. regenerated:

> "**Baseline:** three tight rows, pills nearly touching, minimal vertical separation. **Regenerated:** the five modes wrap into three rows that clearly **breathe** — bigger chips, real column gaps, and a visibly larger gap *between* the wrapped rows; the active green pill sits on its own row with obvious air."

And — load-bearing for the experiment's claim — the provenance of that improvement was clean:

> "the FE agent produced this **from a fresh spec→build with only the improved `DESIGN.md`** — it didn't read the old page, and we put *zero pixels* in the markup. So the bisect points clearly: **`DESIGN.md` was the lever.** The self-review bar we held constant turned out to be *adequate once it had a concrete standard to measure against.*"

The assistant stated the thesis result outright:

> "**That's the thesis confirmed for the first time: improve the agent's reference doc → measurably better output, proven by the regeneration sweep.**"

It held the caveat it and the user had agreed on in Chapter 51 — *"one stochastic run — a strong signal, not proof"* — so the claim stays calibrated: the experiment now has its first end-to-end confirmation that the agent-improvement loop *converges* (an input change to a reference doc, alone, moved the output for the better), measured by a from-spec regeneration; it is a single run, not a statistical proof.

**The user confirmed it independently, by eye, on the running server.** The assistant restarted the app on the regenerated code; the user looked and said:

> "This looks amazing relative to before! Our work did the trick."

The assistant echoed back what made the moment count: *"'did the trick' is the result we wanted: the agent-doc change *alone* produced it. That's the thesis working."* The bisect verdict, stated cleanly across the turn: **the lever was the design doc, not the FE self-review** — the self-review wasn't the binding constraint after all; it was adequate once the doc gave it a concrete standard to measure against. (Chapter 50 had named the self-review weakness — the rubber-stamping "breathe" report — as a candidate cause and deferred it as a future `frontend.md` change; the bisect now says that wasn't this round's constraint. The deferred `frontend.md` taste pass remains available as a *deliberate* future lever, no longer a presumed fix.)

**The sweep surfaced its own regen variances — exactly its job.** Because this was a fresh from-spec rebuild, not a patch, parts of the page that weren't pinned by the spec came out different:

> "the intro/result copy was rewritten, and the input placeholders changed from helpful hints ('e.g. 50') to '0' — a small thing to watch (the 'e.g.' hints were arguably nicer). The sweep surfacing these is exactly its job."

Neither is a defect — both are the regeneration doing what it does (everything not pinned is re-derived), and the placeholder downgrade was logged as a candidate future refinement (capture the "e.g." hint pattern in `DESIGN.md`) rather than a blocker. This is the regeneration sweep's *value* visible in miniature: it doesn't just test the change you made, it re-exposes everything the spec doesn't pin, so drift becomes a thing you *see* and decide about.

**Agent-driven? ✅** The improvement that produced the roomier pills lives entirely in `DESIGN.md`; the page was regenerated from spec with zero hand-edited pixels. This is the cleanest possible instance of rule #1 — the durable change was in the agent's reference layer, and the regeneration proved it carried.

---
