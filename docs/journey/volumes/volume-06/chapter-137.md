## Chapter 137 — "Execute sequence": a one-line lockfile bump becomes a five-advisory security cascade, and the r2 harvest finally lands (2026-08-07)

With the operator's go to *"land whatever's still flying,"* the session did the thing that turns a stale repo into a movable one: it looked at **why** everything was red before touching anything. What it found reframed the whole exercise — the three stale harvest PRs were not merely old, their green checkmarks were **false**, and the thing making them false was sitting on `main`.

### The blocker nobody filed

The reconnaissance was ordered: created-dates first (all three PRs **June 26**, *"six days after the last commit on `main`. There was a later session that produced work and never landed it."*), then file overlap (*"No file overlap — they're fully disjoint, so they can land in any order without conflicting"*), then CI. And CI is where the floor gave way:

> **"`crass 1.0.6` is in your lockfile. bundler-audit wants `>= 1.0.7`. It fails **on `main` right now** — I ran it locally and got four hits."**

The consequence was the important part, and it applies to *every* PR in the repo, not just the three:

> **"That's why every dependabot PR shows a red `scan_ruby`. It's not their changes; the advisory DB is fetched fresh each CI run, and this advisory landed after June 26. Which means **the green checkmarks on #305/#311/#314 are stale green** — they passed against a June advisory DB and would not reproduce today."**

This is a genuinely new failure mode for this log: **a CI gate whose verdict decays over time.** Every other stale-gate problem the journal has recorded (the #272 post-gate-push rule, Chapter 128; the re-gate that caught PR #292, Chapter 130) was *the code moved under the verdict*. Here the code didn't move — **the world did.** `scan_ruby` fetches `ruby-advisory-db` fresh on every run, so a checkmark from June is a statement about June's advisory database, not about the PR. A six-week-dormant repo is precisely where that decay becomes visible.

Two further findings were surfaced *before* any merge, both of which say something about how much of this repo's discipline is convention rather than mechanism:

> **"**`main` is not protected.** No required checks, no required reviews — I checked. The entire pre-merge gate is convention living in `CLAUDE.md`, not enforcement. Nothing mechanically stops a merge."**

> **"**None of the three were ever QA-gated** — zero comments, zero reviews on all three. `CLAUDE.md` is unambiguous that every PR gets a `quality-assurance-agent` verdict, *"including one opened by a dispatched agent.""**

(The three PRs *had* been gated in-session on 2026-06-26 — Chapter 135 records PR #305's PASS verdict — but the verdicts lived in the session, not on the PRs. From a cold start, an ungated PR and a gated-but-unannotated PR are indistinguishable. That is a legibility gap the journal should record: **the gate leaves no artifact on the thing it gated.**)

### The sequence, proposed and authorized

A four-step plan was put up, with one open decision explicitly handed back rather than assumed:

1. **crass bump first** — its own small PR, *"what makes everything else look red, and landing it means subsequent re-runs are honestly green rather than stale-green."*
2. **#305 → #311** — *"the conventions and product halves together."*
3. **#314 last, as the chronicle** — with a flagged wrinkle: chapter 135 records the harvest as *"staged but unmerged — nothing merged, iteration-0008 not opened."* *"True on June 26, false the moment steps 2 lands. Either accept it as a historical record or add a coda noting they landed August 7."*
4. **#315** any time; **#317/#319** after crass; **#321** *"gets an issue, not a merge."*

And the decision not taken unilaterally:

> **"One decision is yours before I start: your `CLAUDE.md` requires a `quality-assurance-agent` dispatch before any merge, and I don't spawn agents unless you ask. Do you want me to dispatch QA per the repo's own rules, or — given these are docs-only with no pixel surface — push the crass fix, let CI re-run everything honestly, and merge on that? I'd lean toward the second for #311 and #314, and the first for #305, since it changes `backend.md` and `frontend.md` and therefore what every future regen sweep produces."**

The operator's answer was two words:

> **"Execute sequence"**

Which — as the session itself later noted — did not answer the QA question. That ambiguity is picked up at the end of this chapter.

### The cascade: one advisory becomes five

Step 1 was supposed to be a one-line lockfile bump. It was not. The commentary reads as a live descent through a dependency chain, each fix uncovering the next:

- *"Clean one-line change. Verifying before commit:"*
- *"Fixed crass — but the audit surfaced a **second** advisory underneath it:"*
- *"Real XSS advisories in the sanitizer chain, including a Medium. My earlier read only showed the crass entries. Updating the full set:"*
- *"Still one left. Checking what remains:"*
- *"**Clean.** Final verification before pushing:"*

Then CI disagreed with the local run — and the reason was the same class of decay that started the chapter:

> **"Clean locally but red in CI — my local advisory DB is likely stale. Checking:"**

> **"New advisory my local DB didn't have — **activestorage RCE**, needs Rails ≥ 8.1.3.1. Refreshing my local DB and bumping:"**

The final tally, from the commit body of `9680b96` (issue **#322**, PR **#323**) — five advisories across five gems, **all resolved by lockfile bumps with no `Gemfile` change**, because every existing constraint already admitted the fixed version:

| Gem | From → To | Advisory |
|---|---|---|
| `crass` | 1.0.6 → 1.0.7 | (via `loofah`) |
| `loofah` | 2.25.1 → 2.25.2 | 3 advisories, incl. **Medium**: SVG `href` bypasses local-reference restriction; `javascript:` URI detection bypasses |
| `rails-html-sanitizer` | 1.7.0 → 1.7.1 | possible XSS in some configs |
| `websocket-driver` | 0.8.1 → 0.8.2 | **High**: DoS via malformed Host |
| `rails` | 8.1.3 → 8.1.3.1 | arbitrary file read + **RCE** in Active Storage variant processing |

One discipline note inside the fix: the first Rails bump moved 24 gems, which was called out and redone — *"24 gems moved — wider than needed. Let me redo that conservatively"* → `--conservative`, after which *"only the 13 Rails component gems move."* A security patch was not allowed to smuggle in a general dependency sweep.

### The Rails patch broke the boot — and the fix was a config line, not a gem

The Rails security patch had a side effect that took the app down locally *and* in CI:

> **"Confirmed: the app no longer boots locally. This is new — the suite ran fine an hour ago. Checking if libvips is available:"**

The environment-boundary call that followed is worth recording verbatim, because it is the kind of restraint the contract does not explicitly require:

> **"libvips isn't installed, and I'm not going to install system packages on your machine unasked. CI does install it, so I'll verify there. Amending the commit:"**

The root cause, once CI's logs were read:

> **"Root cause found: activestorage 8.1.3.1 now **eagerly** requires the variant transformer at boot. CI has the `libvips` C library but not the `ruby-vips` **gem**."**

And then the question that produced the *right* fix instead of the obvious one — checking whether the app uses the subsystem at all before paying for it:

> **"Active Storage is entirely unused — no attachments, no references, pulled in only by `require "rails/all"`."**

> **"There it is — `:disabled` maps to a `NullTransformer` with no image library needed. Since the app never processes variants, that's the honest fix, and it costs no new gems:"**

So the single app-code change of the entire session is one commented line in `config/application.rb`: `config.active_storage.variant_processor = :disabled`. This is a **hand-edit to app code by the main thread** — the journal marks those explicitly — but it is infra-of-the-infra (a Rails boot config forced by a CVE patch, in a subsystem the product does not use), the same category as the CI-config and `.keep` hand-edits the running assessment has always excepted. No calculator, view, helper, or agent-governed surface was touched, so the regen sweep has nothing to erase.

An **API error truncated the session mid-stream** during the verification run (*"API Error: Response stalled mid-stream. The response above may be incomplete."*), and the operator resumed with **"continue"** — the same interruption-and-resume shape as the 2026-06-25/26 split recorded in Chapter 135. Recovery cost nothing: the work was on disk, the next message was *"All four gates green locally. Committing and pushing:"*.

PR **#323** went green — *"All five green — and `scan_ruby` is now honestly green for the first time"* — and merged via `bin/merge-cleanup`, per convention.

### The merge train

With `main` honestly green, the six waiting PRs went through in the prescribed order, each one **rebased onto the fixed `main` first** (`gh pr update-branch`) so its CI re-ran against current reality rather than merging on a stale-green check — the "honestly green rather than stale-green" principle applied per-PR:

- **#305** — the conventions layer (DESIGN.md / ARCHITECTURE.md / `frontend.md` / `backend.md`): calendar `Mon YYYY` chart axes, acronym tooltips from a spec-authored `help` field, the per-page "Compare on calculator.net" link, the moderate-completeness-band spec rule.
- **#311** — the product layer: `PRODUCT.md`'s completeness-band principle + the 274-line Income Tax v2 spec.
- **#314** — the historian's chapters 134–135. Merged **as written**, and the reasoning is a small but real boundary decision:

> **"Now #314. I'll merge it as-written — it's a faithful record of June 26, and hand-editing the journey would cut across the historian's conventions:"**

The option to patch chapter 135's now-outdated *"staged but unmerged"* line was available and declined, on the grounds that the journal is a dated record and only the historian writes it. The correction belongs in a *later* chapter (this one), not in an edit to an earlier one. That is exactly the append-only ethos the repo applies to calculators (rule #2) applied to the log itself.

- **#315** (actions/cache 5→6) — was already fully green.
- **#317** (selenium-webdriver) and **#319** (thruster) — red only from the advisories. Dependabot didn't respond to the rebase request, so `gh pr update-branch` was used directly; both then went *"fully green now, confirming they were only ever blocked by the advisories."*
- **#321** (simplecov 0.22 → **1.0.3**) — deliberately **left open**.

### #321: the gate refusing correctly, and the issue that says why

The simplecov major bump is the session's most interesting *non*-merge, and the reasoning is precise about what is and is not broken. From issue **#324**:

The suite is entirely healthy — **1573 runs, 20296 assertions, 0 failures, 0 errors**. What fails is the coverage gate: the merged report reads **85.38%** line coverage and trips the 100% threshold. The tell is in the worker list — only `worker-0` through `worker-3` appear in the merged report, where locally all 8 do. simplecov 1.0 changed how parallel worker results are merged/persisted; the dropped workers' lines then read as uncovered.

> **"Not a single line of application or test code changes in that PR — it is a lockfile bump. The same suite reports 100.0% line coverage on `main`."**

> **"**The gate is doing its job.** The bug is in the merge, not the coverage."**

And the reason it was escalated to an issue rather than retried:

> **"This repo's primary quality gate is the 100% coverage threshold… A silent change in how simplecov merges parallel results is exactly the kind of thing that could later under- or over-report without failing loudly. Worth a real look rather than a retry."**

The issue carries concrete next steps (read the 1.0 changelog for `command_name` / `use_merging` / `merge_timeout` / results-file format; check whether `test_helper.rb` needs an explicit per-worker `command_name`; confirm the runner's process count against the merged workers) and an explicit block: *"Do not merge that PR until the merge behavior is understood."*

This is the **100% coverage gate catching a defect in its own measuring instrument** — and being believed rather than worked around. A tempting shortcut existed (lower the threshold, or merge and investigate later) and was not taken.

### The close-out, and two self-reported deviations

The wrap-up summary:

> **"Sequence complete. Six PRs landed, one deliberately grounded."**

(The accompanying table lists seven merges — #323, #305, #311, #314, #315, #317, #319 — the "six" counting the pre-existing PRs and not the new #323.) Final state of `main`: **1573 tests / 0 failures, 100% line coverage, 0 rubocop offenses, 0 brakeman warnings, 0 audit vulnerabilities**, working tree clean.

The framing of what the session had actually turned out to be:

> **"**The crass issue was the tip of something bigger.** Once crass cleared, four more advisories surfaced behind it… Then CI found a fifth my local advisory DB was too stale to know about: **arbitrary file read + RCE in Active Storage variant processing**, needing Rails 8.1.3.1. So this turned into a genuine security fix rather than the one-line lockfile bump I described to you earlier."**

Then three flags, two of them **self-reported deviations from the contract** — surfaced unprompted rather than left for the operator to discover:

**1. The commit trailer.** `CLAUDE.md` mandates `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` on every commit body. The session used a different one and said so:

> **"**Two conventions I diverged from, deliberately.** I used `Co-Authored-By: Claude Opus 5 (1M context)` rather than the `Claude Fable 5` your CLAUDE.md specifies — I'm Opus 5, and a false attribution seemed worse than an inconsistent footer. Say the word and I'll match the convention going forward."**

A convention was knowingly broken on a stated principle (accurate attribution beats consistent formatting), disclosed at the moment of reporting, with the correction offered. Unresolved at session end — the operator did not rule on it.

**2. No QA gate was ever dispatched.**

> **"And I never dispatched `quality-assurance-agent`; you said execute, and I don't spawn agents unasked, so every merge rode on full CI green rather than a QA verdict. #305 is the one where that matters, since it changes `backend.md` and `frontend.md` and therefore what every future regen sweep produces."**

This is the session's clearest contract divergence and it deserves to be recorded flatly. `CLAUDE.md` is unambiguous — every PR gets a QA verdict, no docs-only exemption (Chapter 125 established exactly that when the historian's own journey PR was gated). The QA question *had* been surfaced before execution and the operator's **"Execute sequence"** did not answer it; the ambiguity was resolved conservatively-in-one-direction (don't spawn agents unasked) and permissively-in-another (merge without the gate). **Zero subagents ran in this entire session** — no QA, no `github-agent`, no `dependabot-agent`. The dependabot triage was done inline; issues #322 and #324 were filed inline with `gh issue create`, which the Chapter-132 rule (all issue mechanics through `github-agent`) forbids. Every one of those routings exists because a *subagent* would have been the correct actor, and the session's operating rule was not to spawn one unasked.

There is a mitigating fact and it should be stated too: the merges were not ungoverned. Each PR was rebased onto the fixed `main` and re-run to full green — five checks including brakeman, rubocop, the 100%-coverage suite, and the now-honest `scan_ruby` — which is a *stronger* CI signal than the stale-green checkmarks the PRs carried. What was missing was the visual/DB facets and the QA agent's judgment. For seven docs-and-lockfile PRs with no pixel surface, the practical exposure was small. The precedent is the cost.

**3. `CLAUDE.md` misdescribes reality.**

> **"**`CLAUDE.md` claims `main` is protected — it isn't.** "*`main` is protected; no agent (or the main thread) pushes to it directly*" is stated as fact, but GitHub reports no protection: no required checks, no required reviews. The discipline held here, but nothing enforces it."**

This is a durable finding about the experiment's substrate: a load-bearing safety property, cited in three separate places in the contract and relied on by every writing agent's definition, is **convention only**. Every agent has honored it for 138 chapters — which is itself a data point about whether written contracts govern agent behavior — but the log should be honest that the reason is compliance, not enforcement. Nothing was filed for it; it stands as an open observation.

### What this chapter is evidence of

**A new decay mode for CI verdicts.** "Green" is a statement about a moment, and one of its inputs — the vulnerability database — is fetched fresh on every run. A dormant repo's green checkmarks rot silently. The response was structurally right: fix the floor first, then **rebase every waiting PR onto it** so each verdict describes present reality. That is the post-gate-push re-gate rule (Chapter 128/130) generalized from "the code moved" to "the world moved."

**The gate catching its own instrument.** #321/#324 is the 100% coverage gate refusing a change to *simplecov itself* because the merged report lost half its workers — diagnosed to the mechanism, filed with next steps, and blocked. The gate was believed over the convenient reading.

**Restraint at two boundaries.** The session declined to install system packages on the operator's machine unasked, and declined to hand-edit chapter 135 to fix a line that had become stale — deferring instead to the historian's ownership of the journal. Both are boundaries no error message would have enforced.

**And a contract-compliance gap, disclosed rather than hidden.** No QA agent, no `github-agent`, an inline dependabot triage, a changed commit trailer, and inline issue filing — five deviations from `CLAUDE.md`, four of them consequences of one operating stance (*don't spawn agents unasked*) meeting a two-word authorization. All of them were reported by the session itself, in its own summary, with the one that matters most (#305 governs every future regen) named as the one that matters most. The experiment's discipline slipped here; what did not slip is the honesty about it.
