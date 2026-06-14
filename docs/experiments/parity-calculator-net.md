# Parity Audit — whizwheel vs. calculator.net

**Date:** 2026-06-14
**Author:** project-manager-agent
**Scope:** the 8 calculators completed end-to-end (BE + FE merged) as of iteration 0004.

This is a quantitative parity audit. For each completed calculator we cross-checked our
build against its source page on calculator.net and scored how closely we reproduce what
the source *offers* — its inputs, modes/operations, output figures, and options/features
(units, tables, charts, settings).

Sources were enumerated by fetching each calculator.net page on 2026-06-14. Our side was
read directly from `app/calculators/<name>.rb` (the math), the calculator's `spec:v1`
issue body (the durable intent), and the rendered page (`app/views/calculators/<name>.html.erb`
+ `app/views/calculators/results/_<name>.html.erb`).

> **Caveat on source enumeration.** calculator.net pages are fetched and summarized by a
> small model; a couple of the summaries are coarse (e.g. the Tip page's "basic" vs.
> "shared bill" split, the Simple Interest "solve-for tabs"). Where a source feature is
> material to the score we describe it explicitly and, where the summary was ambiguous,
> we flag it rather than assume. Nothing below is scored on a guessed figure.

---

## Rubric (what "match" means — stated rigorously)

We score parity across **four dimensions**, each a set of discrete, countable features:

| Dimension | A "feature" is… |
|---|---|
| **Inputs** | a distinct user-supplied input field (e.g. age, gender, height, units, start date, extra payment). |
| **Modes / operations** | a distinct operation or solve-for variant the page exposes (e.g. percentage-difference vs. percentage-change; solve-for-balance vs. solve-for-rate). |
| **Outputs** | a distinct computed result figure shown to the user (e.g. BMI value, category, healthy-weight range, BMI Prime; total interest; per-person total). |
| **Options / features** | a unit selector, a table, a chart, or a settings toggle that changes what is shown or computed. |

**Match** = the source feature is **functionally present** in our build — the same input
collected, the same operation selectable, the same figure computed and rendered, or the
same option offered. A feature we render *differently* (e.g. a stacked bar where the source
draws a gauge) still counts as a match if it conveys the same information; a feature the
source has and we simply do not produce is a **gap**.

**Excluded from the denominator** (these are not calculator *functionality*, so counting
them would unfairly deflate parity):

- **Educational prose** — formula explanations, worked examples, "how age is calculated
  worldwide" essays.
- **Marketing / reference content** that is not a computed result — the Tip page's global
  tip map and "typical tips by service" table; downloadable CDC growth-chart PDFs;
  static formula-wheel diagrams.
- **Cross-links** to other calculators in the catalog (we catalog those separately in
  `inventory.md`; they are not features *of this* calculator).

These exclusions are listed per-calculator under "Excluded / non-functional" so the
denominator is auditable.

**Parity %** = `matched source features ÷ total source functional features`, computed over
the union of the four dimensions. We report it per calculator and aggregate two ways:
a **simple mean** across the 8, and a **feature-weighted** figure (total matched ÷ total
source features) so a feature-rich calculator (BMI, Amortization) carries proportional
weight.

**Correctness parity** is tracked separately from feature parity: for each calculator we
note whether our reference-value tests reproduce the source's behavior to the figure. A
calculator can be 100% correct on the features it *does* have while still missing features.

---

## Per-calculator detail

### 1. Percentage — `percent-calculator.html`

**Source offers:** three tools on one page — (a) the main "P × V1 = V2" calculator,
exposed phrased three ways (what is X% of Y / X is what % of Y / X is Y% of what);
(b) the Percentage Difference calculator; (c) the Percentage Change calculator with an
Increase/Decrease toggle. No units, no tables, no charts.

**We offer:** all five operations as `mode` (`percent_of`, `what_percent`, `percent_of_what`,
`difference`, `change` with `increase`/`decrease` direction) — a one-to-one superset of the
source's three tools (the main tool's three phrasings are our first three modes).

| Dimension | Source | Covered | Missing |
|---|---|---|---|
| Inputs | v1/v2/percent + direction toggle | all | — |
| Modes/operations | 5 (3 main phrasings + diff + change) | 5 | — |
| Outputs | the solved figure per operation | all | — |
| Options/features | Increase/Decrease toggle | yes | — |

**Source functional features:** 8 · **Covered:** 8 · **Parity: 100%**
**Gaps:** none. **Our additions:** none material (we match exactly).
**Correctness:** reference-value tests pass for all five modes incl. div-by-zero guards.
**Excluded / non-functional:** the formula definition + worked-example prose.

---

### 2. BMI — `bmi-calculator.html`

**Source offers:** inputs Age, Gender, Height, Weight, and a **US / Metric / Other** unit
selector. Outputs: BMI value, category, **healthy BMI range (18.5–25)**, **healthy weight
range for this height** (in lb or kg), **BMI Prime**, **Ponderal Index**. A visual gauge
pinning the BMI on a spectrum. An **adult vs. child/teen** distinction — for ages 2–20 it
uses CDC percentile categories, a genuinely different classification mode. Reference tables
(adult BMI table, CDC tables) and downloadable growth-chart PDFs.

**We offer:** inputs Weight, Height, and a **US / Metric** unit selector. Outputs: BMI value
+ WHO category. A thin stacked-bar scale with a marker (our analogue of the gauge) and a
band legend. We do **not** collect age or gender, do **not** do the child/teen percentile
mode, and do **not** compute healthy-weight-range, BMI Prime, or Ponderal Index.

| Dimension | Source | Covered | Missing |
|---|---|---|---|
| Inputs | Age, Gender, Height, Weight, units | Height, Weight, units (3) | **Age, Gender** (2) |
| Modes/operations | Adult (WHO) + Child/Teen (CDC percentile) | Adult (1) | **Child/Teen percentile mode** (1) |
| Outputs | BMI, category, healthy-BMI-range, healthy-weight-range, BMI Prime, Ponderal Index | BMI, category (2) | **healthy-weight-range, BMI Prime, Ponderal Index** (3); healthy-BMI-range is implicit in our legend |
| Options/features | US/Metric/Other units, visual gauge, adult BMI table | US/Metric units, scale bar (2) | **"Other" units, adult BMI reference table** (2) |

**Source functional features:** 15 · **Covered:** 8 · **Parity: 53%**
**Gaps (ranked):** child/teen CDC mode (needs Age + Gender); healthy-weight-range; BMI Prime;
Ponderal Index; the "Other" mixed-unit option; an adult BMI reference table.
**Our additions:** an 8-band WHO breakdown (the source's table is coarser in its inline
classification) and a per-band marker — a richer scale render than the source's gauge.
**Correctness:** the BMI figure + WHO band match the source to 1 dp across 8 reference rows
(incl. the cross-unit 72.57 kg ≡ 160 lb / 70 in = 23.0 check).
**Excluded / non-functional:** CDC growth-chart PDFs, the formula prose.

---

### 3. Ohm's Law — `ohms-law-calculator.html`

**Source offers:** four quantities V/I/R/P, "provide 2, solve for 2." Per-quantity **unit
selectors** (V: kV/V/mV; I: A/mA; R: Ω/kΩ/MΩ; P: W/kW/MW/hp/BTU·h). A circuit diagram and
formula wheel (static).

**We offer:** the same four quantities and the same six "provide-2-solve-2" modes, with all
four figures echoed/solved. We do **not** offer the per-quantity unit selectors — inputs and
outputs are in base units (V, A, Ω, W) only.

| Dimension | Source | Covered | Missing |
|---|---|---|---|
| Inputs | V, I, R, P (any 2) | all 4 | — |
| Modes/operations | 6 input-pairs (vi/vr/vp/ir/ip/rp) | all 6 | — |
| Outputs | V, I, R, P (full set each time) | all 4 | — |
| Options/features | 4 unit selectors (V/I/R/P with multiple prefixes) | none | **all 4 unit selectors** |

**Source functional features:** 18 · **Covered:** 14 · **Parity: 78%**
**Gaps:** the four unit selectors (kV/mV, mA, kΩ/MΩ, kW/MW/hp/BTU·h). The math is complete;
the gap is purely unit-prefix ergonomics.
**Our additions:** explicit Given/Solved tagging of each quantity (clearer than the source's
plain four-field output).
**Correctness:** all six modes pass reference values, incl. the cross-mode "same circuit
three ways" check and the rp √(P/R) branch.
**Excluded / non-functional:** circuit diagram, formula-wheel graphic.

---

### 4. Tip — `tip-calculator.html`

**Source offers:** Price (bill), Tip %, Number of People; outputs tip amount, total, tip
per person, total per person. (The page is framed as a "basic" tip calc + a "shared bill"
calc, but functionally that is one form with a people field.) No rounding toggle or tax
field is exposed in the interface. The bulk of the page is the global tip map + the
typical-tips-by-service reference table (content, not computation).

**We offer:** Bill, Tip %, People; outputs tip amount, total, tip-per-person, total-per-person,
plus a bill-breakdown table and a per-person split block. A one-to-one functional match.

| Dimension | Source | Covered | Missing |
|---|---|---|---|
| Inputs | bill, tip %, people | all 3 | — |
| Modes/operations | single (basic ≡ shared-bill with people=1) | yes | — |
| Outputs | tip, total, tip/person, total/person | all 4 | — |
| Options/features | (none functional exposed) | n/a | — |

**Source functional features:** 7 · **Covered:** 7 · **Parity: 100%**
**Gaps:** none functional. *(If the source's hidden interface exposes a "round the total"
toggle or a tax field — not visible in the fetch — that would be a 1–2 feature gap; flagged,
not scored.)*
**Our additions:** a structured bill-breakdown table and a labeled N-way split block.
**Correctness:** 6 reference rows pass, incl. the per-person rounding note (per-person
derived from raw, may not sum to the whole-party figure).
**Excluded / non-functional:** global tip map, typical-tips-by-service table, tip etiquette
prose.

---

### 5. Simple Interest — `simple-interest-calculator.html`

**Source offers:** Principal, Rate, Term (years **and** months). **Solve-for tabs** — the
page lets you solve for Balance, Principal, Term, **or Rate** (four solve-for variants).
Outputs: total interest, end balance, **shown calculation steps**. A **balance-accumulation
graph**, a **principal-vs-interest pie chart**, and a **year-by-year schedule table**.

**We offer:** Principal, Rate, Time with a Years/Months unit selector; outputs interest +
total, plus a principal+interest=total breakdown table. We solve for the **balance only** —
not for principal, term, or rate. We have **no** accumulation graph, **no** pie chart, and
**no** year-by-year schedule.

| Dimension | Source | Covered | Missing |
|---|---|---|---|
| Inputs | principal, rate, term, years/months unit | all 4 | — |
| Modes/operations | 4 solve-for (balance / principal / term / rate) | balance (1) | **principal, term, rate** (3) |
| Outputs | interest, end balance, calc steps | interest, total (2) | **shown calc steps** (1) |
| Options/features | years/months unit, accumulation graph, pie chart, yearly schedule table | years/months unit (1) | **accumulation graph, pie chart, yearly schedule** (3) |

**Source functional features:** 12 · **Covered:** 8 · **Parity: 67%**
**Gaps (ranked):** the three inverse solve-for modes (principal/term/rate); the yearly
schedule table; the two charts (accumulation + pie). The forward math is complete and correct.
**Our additions:** a clean principal→interest→total breakdown (the source shows steps as prose).
**Correctness:** 6 reference rows pass incl. the months→years conversion and zero edges.
**Note:** this calculator is the clearest "we built the forward case, the source is a small
multi-mode solver with output viz" gap — a good candidate for a v2 spec.

---

### 6. Mean, Median, Mode, Range — `mean-median-mode-range-calculator.html`

**Source offers:** one numbers field; outputs **mean, median, mode, range** (the page's
display shows these four; the fetch did not surface sum/count/min/max as displayed figures,
though the worked example sorts the data).

**We offer:** the same numbers field; outputs mean, median, mode (as an array — "23 and 38" /
single / "No mode"), range, **plus sum, count, smallest, largest** (eight figures).

| Dimension | Source | Covered | Missing |
|---|---|---|---|
| Inputs | numbers list | yes | — |
| Modes/operations | single | yes | — |
| Outputs | mean, median, mode, range | all 4 | — |
| Options/features | (none) | n/a | — |

**Source functional features:** 6 · **Covered:** 6 · **Parity: 100%** (with **additions** —
sum/count/smallest/largest beyond the source's four).
**Gaps:** none on the four named statistics. *(If the source's own display includes a sorted
list or sum/count that the fetch missed, those would still be covered by our extras.)*
**Our additions:** sum, count, smallest, largest; correct multimodal + no-mode handling.
**Correctness:** 5 reference rows pass incl. bimodal `[23,38]`, no-mode (all-unique),
single-value, and even-count median.
**Excluded / non-functional:** the related Statistics / Std-Dev / Sample-Size calculators
(separate inventory rows).

---

### 7. Age — `age-calculator.html`

**Source offers:** Date of Birth, "Age at the Date of" (end date). Output age in **years,
months, weeks, days, hours, minutes, and seconds**, plus the Y/M/D component breakdown.

**We offer:** birth_date, end_date (defaults to today); output the Y/M/D calendar breakdown
plus total months, total weeks, total days, total hours. We do **not** emit total **minutes**
or total **seconds**.

| Dimension | Source | Covered | Missing |
|---|---|---|---|
| Inputs | DOB, end date | both | — |
| Modes/operations | single (date-diff, defaults end→today) | yes | — |
| Outputs | Y/M/D breakdown; total months, weeks, days, hours, minutes, seconds | Y/M/D + months/weeks/days/hours | **total minutes, total seconds** (2) |
| Options/features | (none) | n/a | — |

**Source functional features:** 11 (2 inputs + 1 mode + 8 output figures incl. minutes/seconds)
· **Covered:** 9 · **Parity: 82%**
**Gaps:** total minutes and total seconds (trivial: `days × 1440` / `× 86400` — a spec/test
add, no new UI shape).
**Our additions:** a plain-language age phrase ("33 years, 11 months, 30 days old").
**Correctness:** 5 reference rows pass incl. the leap-day `2020-02-29 → 2024-02-28` borrow
and same-day zeros; default-to-today covered by a clock-stub test.
**Excluded / non-functional:** the "how age is calculated worldwide" prose.

---

### 8. Amortization — `amortization-calculator.html`

**Source offers:** Loan amount, Loan term (years **and** months), Interest rate; **optional
Loan Start Date**; **optional Extra Payments** (extra monthly, extra yearly, extra one-time,
plus up to ~10 additional one-time entries). Outputs: monthly payment, total of payments,
total interest, remaining balance, and (via start date) an implied payoff date. A **monthly
amortization schedule**, an **annual summary table**, a **balance-over-time line graph**, and
a **principal-vs-interest pie chart**.

**We offer:** principal, annual_rate, years; outputs monthly payment, total paid, total
interest, number of payments; a full **monthly schedule** (paginated), a **donut**
(principal vs. interest), and a **balance-over-time curve**. We do **not** support a term in
months, a start date / payoff date, any extra-payment inputs, or an annual summary table.

| Dimension | Source | Covered | Missing |
|---|---|---|---|
| Inputs | loan amt, term-years, term-months, rate, start date, extra-monthly, extra-yearly, extra-one-time(+more) | loan amt, term-years, rate (3) | **term-months, start date, extra monthly/yearly/one-time** (5) |
| Modes/operations | base loan + extra-payment scenario | base loan (1) | **extra-payment scenario** (1) |
| Outputs | monthly payment, total paid, total interest, balance, payoff date | payment, total paid, total interest, balance (4) | **payoff date** (1) |
| Options/features | monthly schedule, annual summary table, balance line graph, pie chart, extra-payments toggle | monthly schedule, balance curve, donut (3) | **annual summary table, extra-payments toggle** (2) |

**Source functional features:** 18 · **Covered:** 11 · **Parity: 61%**
**Gaps (ranked):** extra-payment inputs + scenario (the source's headline differentiator);
term-in-months; start date → payoff date; annual summary table.
**Our additions:** a no-JS-baseline paginated schedule (every row present, then Stimulus
pagination) — arguably a cleaner table UX than the source.
**Correctness:** 4 reference rows pass incl. the zero-rate edge, month-1 breakdown, totals,
and final-balance-lands-on-0.00 reconciliation.
**Excluded / non-functional:** the related-loan cross-links.

---

## Aggregate

| # | Calculator | Source features | Covered | Missing | Parity % | One-line gap |
|---|---|---|---|---|---|---|
| 1 | Percentage | 8 | 8 | 0 | **100%** | full match |
| 2 | BMI | 15 | 8 | 7 | **53%** | no child/teen mode, no Age/Gender, no healthy-weight / BMI Prime / Ponderal |
| 3 | Ohm's Law | 18 | 14 | 4 | **78%** | math complete; missing the 4 unit-prefix selectors |
| 4 | Tip | 7 | 7 | 0 | **100%** | full functional match |
| 5 | Simple Interest | 12 | 8 | 4 | **67%** | only forward solve; no inverse modes, no charts/yearly table |
| 6 | Mean·Median·Mode·Range | 6 | 6 | 0 | **100%** | full match (+ 4 extra stats) |
| 7 | Age | 11 | 9 | 2 | **82%** | missing total minutes + seconds |
| 8 | Amortization | 18 | 11 | 7 | **61%** | no extra payments, term-months, start/payoff date, annual table |
| | **Totals** | **95** | **71** | **24** | | |

**Aggregate parity — two figures:**

- **Simple mean across the 8 calculators: 80.1%**
  `(100 + 53 + 78 + 100 + 67 + 100 + 82 + 61) ÷ 8`
- **Feature-weighted (total covered ÷ total source features): 71 / 95 = 74.7%**

The feature-weighted figure is lower because our two biggest misses (BMI, Amortization) are
also the two most feature-rich source pages — exactly where weighting bites. We report both;
**74.7% feature-weighted is the more honest single number** for "how much of calculator.net's
functionality do these 8 pages reproduce."

**Correctness parity: 100%.** Every calculator reproduces its source's behavior to the
figure across its reference-value table — we are not *wrong* anywhere; we are *narrower*.
The gap is consistently **scope** (modes, inverse solves, extra-payment scenarios, secondary
output figures, unit prefixes), never accuracy. This matches the project's build model: each
calculator's `spec:v1` pins a forward, single-mode core and we build precisely that.

---

## Prioritized gap list (what to build next)

Ranked by parity lift per unit of effort — cheap, high-coverage wins first.

1. **Age → total minutes + seconds** *(trivial; +2 features → Age to 100%).* Pure spec/test
   add (`days × 1440`, `× 86400`); no new UI shape. The single cheapest parity win in the set.
2. **Ohm's Law → unit-prefix selectors** *(medium; +4 → Ohm's to 100%).* Math is done; this
   is a per-field unit dropdown + scaling. First real `unit-conversion`-on-input exercise —
   would also de-risk the many `unit-conversion`-tagged calculators in the backlog.
3. **BMI → healthy-weight-range + BMI Prime + Ponderal Index** *(low-medium; +3 → BMI ~73%).*
   All three are one-line formulas off the existing inputs; no new inputs needed. Knocks out
   the three cheapest BMI gaps before the expensive ones.
4. **Simple Interest → inverse solve-for modes (principal / rate / term)** *(medium; +3 →
   ~92%).* A `mode`/solve-for picker over the same formula — directly reuses the multi-mode
   pattern Percentage/Ohm's validated. A clean test of "solve-for-the-unknown" as a reusable
   shape (it recurs in Finance, Interest Rate, Investment).
5. **Amortization → extra payments + term-in-months + annual summary table** *(high; +5 →
   ~89%).* The source's headline differentiator and the biggest single scope gap. Extra
   payments change the schedule recurrence; the annual table is a roll-up of rows we already
   compute. High value, highest effort — best as its own spec'd v2.
6. **BMI → child/teen CDC percentile mode (needs Age + Gender)** *(high; +4 → ~100%).* A
   genuinely separate classification mode requiring new inputs and CDC percentile data.
   Largest BMI lift but the most data-heavy; defer behind the cheap BMI wins above.

**Theory this surfaces for sequencing:** our parity gap is almost entirely **(a) inverse /
multi-mode solving** and **(b) input-side unit conversion** — two reusable shapes, not 8
one-off features. Building #2 (Ohm's units) and #4 (Simple-Interest inverse modes) would
encode both shapes into the agents once and lift the *whole backlog's* expected parity, not
just these two pages. That is the higher-leverage path than chasing per-calculator
long-tail outputs.

---

*Generated by the project-manager-agent as an analysis/reporting task. No app code or
calculators were modified. Source enumeration: calculator.net pages fetched 2026-06-14;
our side: `app/calculators/`, the `spec:v1` issue bodies, and `app/views/calculators/`.*
