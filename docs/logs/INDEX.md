# Iteration Log Index

Registry of all iterations. Each iteration is pinned to a committed agent set (SHA) and
tagged `iteration-NNNN`. Detail lives in `logs/iteration-NNNN/`.

| Iteration | Status | Opened | Closed | Agent SHA | Calculators (issues) | Headline outcome |
|---|---|---|---|---|---|---|
| 0001 | closed | 2026-06-13 | 2026-06-13 | `c7796eb` | Percentage (#30 BE / #31 FE) | Percentage shipped end-to-end BE+FE — first full spec→build→measure loop; cramped pills + a self-review that missed them → iteration 0002 invests in a DESIGN.md spacing system. |
| 0002 | closed | 2026-06-13 | 2026-06-13 | `1e18ce2` | Percentage (regen — frontend; spec #31) | Spacing scale validated by regeneration: better DESIGN.md guidance alone produced roomier pills (Grouped-wrapping `gap-x-3 gap-y-4`) from spec + DESIGN.md only — first confirmation of the agent-improvement loop; bisect points to DESIGN.md, not the self-review, as the lever. Single-sample signal, not proof. |
| 0003 | open | 2026-06-14 | — | `0ca4a02` | BMI Calculator (#52 BE / #53 FE), Ohms Law Calculator (#54 BE / #55 FE); + Percentage regen (#30 BE / #31 FE) | — |
<!-- Populated by the PM agent via the Iterations capability. -->
