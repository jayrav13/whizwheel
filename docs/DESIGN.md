# whizwheel — Design System (BLEND)

**Status:** Living document. This is the **single source of truth for how whizwheel *looks*.** Every UI build (the frontend agent, any view work) ingests this before writing markup, the way `ARCHITECTURE.md` is ingested before writing app code. Its siblings: [`ARCHITECTURE.md`](ARCHITECTURE.md) (*how* we build) and [`PRODUCT.md`](PRODUCT.md) (*what* we build). When the look changes, it changes **here first**.

The aesthetic is named **BLEND** — *warm, sharpened, with a touch of green.* It is a deliberate departure from calculator.net's ad-heavy grey: warm and approachable (soft cream, rounded cards, a donut for breakdowns), but **sharpened** with a crisp grotesk, tight sweeping headlines, and tabular numerals so dense financial data stays precise and authoritative.

---

## 0. Principles

1. **Distinctive and usable, not generic** (`PRODUCT.md`). The UI should feel made, not defaulted.
2. **Warm chrome, precise data.** Coral/cream/rounded for the frame and actions; tabular numerals, thin rules, and clear hierarchy for the numbers.
3. **Green is a touch, not a theme.** Coral leads actions and chrome; green is an accent (see §1).
4. **The system is enforced by tokens, not by memory** — see the guardrail in §5.
5. **Server-rendered, progressively enhanced.** Hotwire/Turbo + minimal Stimulus; the UI renders the JSON envelope from `ARCHITECTURE.md §4` and these tokens — nothing else.

---

## 1. Color tokens

| Token | Value | Use |
|---|---|---|
| `bg` | `#fdf8f3` | page background (warm cream) |
| `surface` | `#ffffff` | cards, panels |
| `ink` | `#241d18` | primary text, hard numbers |
| `muted` | `#6f6155` | body / lede text |
| `label` | `#8a7768` | field labels |
| `faint` | `#a08a7c` | table headers, de-emphasis |
| **`primary`** (coral) | `#ef6c4d` | primary actions (buttons), hero accent rule |
| **`accent`** (green) | `#2f9e6f` | brand dot, active tab, largest chart slice, eyebrow, positive stats |
| `amber` | `#ffb703` | tertiary chart slice |
| `border` | `#f3ebe2` | card borders |
| `border-input` | `#ece1d6` | input borders (focus → `accent`) |
| `rule` | `#efe4d8` | table rules |

**Green is a touch, coral leads.** Green appears only on: the brand dot (with halo `rgba(47,158,111,.16)`), the active tab, the donut's largest slice (e.g. principal & interest), eyebrow labels, and select positive stats. Everything actionable (buttons, primary affordances) and the brand chrome is **coral**.

**Contrast:** verify coral and green meet **WCAG AA** for their text/background pairings (e.g. white text on coral, green text on cream). Never rely on color alone to convey meaning.

**Candidate token (watch, don't mint yet):** the selected-row tint on the Mode picker's active option (§4) currently uses the opacity utility `bg-accent/8`. If that subtle accent wash recurs across components, promote it to a named `--color-accent-tint` token (and a row here); until it does, leave it as the `bg-accent/8` utility — don't invent the token's value prematurely.

---

## 2. Typography

- **Family:** a sharp grotesk — `"Inter", "Helvetica Neue", system-ui, sans-serif`. **Inter is self-hosted** — one variable `woff2` (latin subset, weights 400–800) declared via `@font-face` in `app/assets/tailwind/application.css` and served by Propshaft (no Google-Fonts CDN at runtime) — so the grotesk is delivered on every OS, not left to system availability. The other entries are fallbacks during load / if it fails to fetch.
- **Headlines:** weight **800**, tracking **`-0.035em`**, large and *sweeping*. Page title ≈ **40px**; hero result ≈ **54px** at `-0.04em`.
- **Numerals:** **`tabular-nums`** wherever numbers matter (hero results, chart amounts, schedules, stats) so columns align.
- **Money → always 2 decimals (cents):** any **displayed monetary / dollar figure** renders with **exactly two decimal places** — `$1,000.00`, `$463.16`, `$0.00` — **never** `$1,000`, `$1,000.5`, or `$1000`. This holds **everywhere a money value is shown**: hero results, stat-grid cards, breakdown tables, schedule tables — every presented currency figure. Thousands separators stay; the cents are never dropped or left ragged (a whole-dollar value is `.00`, not bare). This is a **presentation-formatting rule for money only** — non-money numbers (rates, percentages, counts, plain quantities) keep their **own** existing precision rules and are **not** forced to 2dp. (It applies to *formatted presentation figures*, not the raw-echoed `<code>` values below — those quote back exactly what was entered.)
- **Raw / echoed data → monospace `<code>`:** any **block of verbatim quantitative or structured data echoed back to the user** renders in a **monospace `<code>`** treatment (Tailwind `font-mono`, in a real `<code>` element). The canonical case is the **admin stats recent-activity feed**, where each row's **input → result values** are raw echoed data — wrap those quantitative summaries in `<code>` (e.g. `<code class="font-mono">{rate: 5.5, years: 30}</code>`), never plain prose. This is a deliberate, scoped treatment for *raw echoed values* (recent-activity input/result summaries, raw key/value or JSON-ish dumps, IDs) — it is **not** for **formatted presentation figures** in stat cards, hero results, or data-table cells, which stay `tabular-nums` grotesk (see Numerals). The distinction: a *presented answer* is grotesk + `tabular-nums`; *raw data being quoted back* is `<code>` monospace.
- **Eyebrow:** 11px, `.12em`, uppercase, **green**.
- **Labels:** 12px, bold, `label` color.
- **Acronyms always carry their expansion.** Any **acronym or jargon term** in a field label, output label, or result is rendered with a **hover/focus tooltip** giving its plain-language expansion (DTI → "Debt-to-Income ratio") — see §4 *Abbreviation / term tooltip*. **Never an unexplained acronym** (the iteration-0007 review hit House Affordability's bare "DTI").
- **Lede / body:** 15px, `muted`, line-height ~1.5.

---

## 3. Shape & spacing

- **Radii:** cards `18px`, inputs `11–13px`, buttons `13px`, pills/tabs `999px`.
- **Card:** `surface` background, `1px` `border` outline, shadow `0 10px 34px rgba(150,110,80,.12)`.
- **Whitespace:** generous. Let pages breathe; density is achieved with rules and alignment, not crowding.
- **Spacing scale (the rhythm).** Spacing encodes **relationship — closer = more related**; pick the tier by *what the gap separates*, not by habit. These are **targets, not minimums** — when unsure, go one step *more* open (a too-tight layout is the failure mode, not a too-airy one).

  | Tier | Token | Separates |
  |---|---|---|
  | **Affix** | `gap-2` (8px) | parts of one control (a `%`/unit ↔ its field); a segmented toggle's halves may go tighter (`gap-1`) |
  | **Grouped** | `gap-3` (12px) | sibling controls in a set — pills in a row, stat-grid cards |
  | **Grouped, wrapping** | `gap-x-3 gap-y-4` (12 / 16px) | a control group that **wraps** — row-gap **one step larger** than column-gap |
  | **Stacked** | `space-y-5` (20px) | stacked fields down a column |
  | **Section** | `mt-7`–`mt-8` (28–32px) | major blocks within a card (mode → fields → submit) |
  | **Layout** | `gap-8` (32px), `p-6`–`p-8` | column gutters, card padding |

  Two rules travel with the scale: **(1)** a **wrapping** control group gets a **larger row-gap than column-gap** (`gap-y` > `gap-x`) so wrapped rows read as a grid, never a clump; **(2)** tappable **chips/pills need air** to read as distinct, separately-hittable targets — never keypad-dense.
- **Layout grid:** desktop = an input column + a results panel (roughly `380px 1fr`); collapses to a single stacked column on mobile (**mobile-first**).

---

## 4. Component vocabulary (the reference library)

The login/home pages are the first **reference implementation**; new pages copy these patterns.

- **Nav** — whizwheel wordmark + the **green dot** (with halo); right-side links (Calculators, History, and the auth affordance: *Sign in* or *Signed in as {username}* + *Sign out*).
- **Footer** — quiet, `faint`/`muted`, single row.
- **Flash** — `success` (green-leaning) and `alert` (coral/red-leaning) banners; legible, dismissible-looking, never raw browser text. The failed-login *"Invalid username or password"* alert is the canonical `alert`.
- **Input** — labeled; optional `$` / `%` / unit affix; `border-input` border, focus ring → `accent`; `tabular-nums` for numeric inputs.
- **Date field with "Today" quick-fill** — for an **optional** date whose *blank value means "today"* — an as-of / end / measure-to date (e.g. the "as of" date in an Age calc, a loan's payoff-as-of date). Pair the date input with an explicit **"Today" quick-fill button** (a small secondary affordance beside the field) that fills the current date on tap. **Never silently auto-prefill** the field — blank stays blank until the user acts, so the "today" default is visible and chosen, not hidden. And **never auto-default a required / primary date input** (e.g. a birth date): those carry no "today" meaning and must be entered, with no quick-fill button.
- **Validation errors** — when the envelope returns `errors` (`ARCHITECTURE.md §4`), surface them in a coral-tinted card (eyebrow e.g. *"Check your input"*). **Phrase each message against the field's visible label, never the raw attribute key** — "Value can't be blank", not "v1 can't be blank". The UI knows the labels it rendered; map the error key → that label.
- **Abbreviation / term tooltip** — any **acronym or jargon term** in a field label, output label, or result (House Affordability's **DTI**, an **APR** / **CAGR** / **LTV**) renders as a real **`<abbr>`** with a **hover *and* keyboard-focus tooltip** giving the plain-language expansion (`DTI` → "Debt-to-Income ratio"). The expansion text is **supplied by the backend per field in the §4 envelope** (the per-input `help` / abbreviation text — `ARCHITECTURE.md §4`), **not** a frontend-maintained glossary, so the definition lives with the calculator and survives the regen sweep. A **dotted underline** marks the term (a cue beyond colour, §6); the native `<abbr title>` is the no-JS floor and a styled popover enhances it. **Never ship an unexplained acronym** — if a label needs one, it needs its tooltip (iteration-0007 review: bare "DTI").
- **Primary button** — `primary` (coral), white text, `13px` radius, subtle coral shadow.
- **Tab pills** — a **horizontal, page-level tab set** (switching *views* of a page, not a calculator's input mode — for the mode/variant picker use **Mode picker** below): a wrapping pill row on the **Grouped-wrapping** spacing tier (§3 — `gap-x-3 gap-y-4`); active pill filled `accent` (green), inactive `faint` on a tint. Pills must read as distinct, breathing, separately-hittable chips — never crowded, even when the row wraps.
- **Mode picker** — for a calculator whose inputs depend on a chosen mode, pick the presentation by **mode count and label length** (the iteration-0007 harvest settled this; the two presentations had diverged — Sales Tax & VAT chose a segmented control for 3 multi-word labels while §4 then mandated the list for *any* multi-word label):
  - **Segmented control — N ≤ 3 with short-ish labels** (the connected horizontal track used by Percentage's Increase|Decrease, BMI's US|Metric, Simple Interest's Years|Months, and Sales Tax / VAT's three solve-for modes). A **short-ish label is OK to be a multi-word phrase that wraps to at most two lines** (e.g. "After-tax price", "Before-tax price" beside a one-line "Tax rate") — a multi-word label **no longer** forces the list, **provided** the segmented halves render robustly: the **equal-height, vertically-centered, wrap-safe** rule below is the safeguard that makes a wrapping two-line pill render cleanly. Use this whenever the picker has **≤3 modes and no single label is long** (roughly ≤ a two-line phrase).
  - **Selectable option list (`.mode-option`) — N > 3, OR any genuinely long label** (a label that would run past ~two lines / needs a helper sentence to explain the mode). A single `border-input` container with `divide-rule` rows, each a full-width `<label>` over a visually-hidden `peer` radio posting `inputs[mode]` — a leading radio glyph (hollow ring → filled accent ring when active, the non-colour cue per §6), a bold `ink` label, and a one-line `muted` helper naming what that mode solves. Active row: accent inset left rule + subtle accent tint (`bg-accent/8` — see §1 candidate-token note); focus-visible: inset ring on the visible row. (Used by Ohm's Law, Percentage's solve-for list, etc.)

  **Segmented halves must be equal-height with vertically-centered text — even when a label wraps** (this is the safeguard that lets a ≤3-mode multi-word picker use the segmented control safely). The track is `flex` (default `align-items: stretch`), so every half already shares the tallest half's height; each half (`.direction-pill`) must then **center its own content** (`items-center justify-center`, with `text-center` for a wrapped two-line label) so a one-line label ("Tax rate") sits vertically centered beside two-line siblings ("After-tax price"), never top-pinned by padding. This is a standing requirement of the shared `.direction-pill` component, not a per-calculator fix — text is vertically centered inside a pill regardless of wrapping. The picker is **always a native radio `<fieldset>`/`<legend>`** posting a single-select `inputs[mode]`; the no-JS baseline (`.peer:checked` paints; server validates) is retained in both presentations. Reserve a native `<select>` for genuinely long menus (N > ~8) only — never as the primary picker.
- **Card** — the base container (§3).
- **Hero-result** — a `surface` card with a **5px coral left rule** and a big `tabular-nums` number; the page's headline answer.
- **Stat grid** — a grid of small stat cards (label + value), built from **one shared component**, never hand-rolled per page. Earlier guidance ("implement a responsive auto-fit grid") let each page inline its own `grid-cols-[repeat(auto-fit,…)]` width, which drifted into **six divergent min-widths** across the catalog (the #143 problem); this is now a single component with a **bounded modifier set**. **The standing rule: use the component and its modifiers — NEVER a per-page inline `grid-cols-[repeat(auto-fit,…)]` width.** Per-page value **size and colour** are utilities on the inner `<dd>` (e.g. a derived/positive figure → `accent`), never a fork of the card shell.
  - **`.stat-grid`** — the single canonical responsive auto-fit track (`grid-cols-[repeat(auto-fit,minmax(9.5rem,1fr))]`), **9.5rem** default min-width: roughly **4 across** on a wide results panel, collapsing to **2×2** when narrow. The `auto-fit` arbitrary value lives **once** here, justified per §5 (the standard scale can't express auto-fit), not per page.
  - **`.stat-card`** — the canonical card shell: inset tint, radius, border, padding, `min-w-0` + `overflow-hidden`. Values are `tabular-nums` and **stats never clip** — this is now structurally enforced: the value `<dd>` carries `overflow-wrap: anywhere`, so a figure that exceeds even the `--wide` track **wraps to a second line rather than clipping**, and data loss can never happen on any stat card. The hierarchy: **single-line is preferred** (that's what choosing `--wide` for a high-magnitude grid buys), **wrapping is the acceptable floor**, and **clipping is never allowed**. The shell's min-width and padding keep ordinary numbers on one line; the `overflow-wrap` net catches the pathological worst case.
  - **`.stat-grid--wide`** — sanctioned modifier, **13rem** min-width, for grids whose realistic worst-case value is **high-magnitude** — whether **unit-bearing**, **money**, or a **plain large unit-less number** — where the default 9.5rem track would wrap the value mid-number in the narrow (~489px) result panel. **Selection criteria:** use it when the worst-case figure is long enough to wrap/clip on the default 9.5rem track — that includes a **long + unit-bearing** value (Ohm's Law `998,001,000 W`), **7+ digit money** (Simple Interest `$1,000,000.00`), **and a large unit-LESS number** (Mean-Median-Mode-Range's 7-digit statistics like `6,419,754`, Age's Total-hours figure). Keep short/plain grids (BMI ranges, Tip, ordinary small money) on the default 9.5rem.
  - **`.stat-card--surface`** — modifier for a stat grid that sits directly on the **page background** rather than nested in a surface-white hero card (Amortization's totals), so the cards stand off the cream.
  - **`.stat-card--solved`** — accent-tinted **state** card (Ohm's Law's solved values vs. given). A modifier, not a fork — and per §6 (never colour alone) it must be paired with the visible **"Solved"/"Given"** tag, so the state reads without relying on the tint.
- **Charts** — **every chart anywhere in the app** — calculator result charts **and** admin / dashboard charts (e.g. the **admin stats volume trend**) — uses a **hover/crosshair/tooltip-capable JS charting library**, delivered via **importmap (no build step)** like the rest of our JS. **TradingView lightweight-charts is our house charting library — default to it; reach past it only for a shape it genuinely lacks (donut).** **Never hand-roll a chart in inline SVG or hand-drawn `<canvas>` code — not even a "simple" bar chart, and not for a dashboard.** A hand-rolled SVG/markup chart is *only* ever the **no-JS fallback** (below), never the primary chart; if you find yourself drawing `<rect>`/`<path>` bars by hand for the actual chart, stop — that's the anti-pattern this rule exists to kill (it is exactly how the first admin stats page shipped a non-library chart). Pick by chart shape:
  - **Line / time-series** (e.g. Amortization's *Balance over time*) → **TradingView lightweight-charts** — crosshair + per-point tooltip on hover.
  - **Bar / histogram / count-over-time** (e.g. the **admin stats 30-day calculation-volume** trend) → **TradingView lightweight-charts `Histogram` series** — the same house library in its bar form, with crosshair + per-bar tooltip. **Do not** substitute a hand-drawn SVG bar chart; lightweight-charts covers this shape natively.
  - **Donut / breakdown** (the principal-vs-interest split, etc.) → a **complementary hover-capable library** (lightweight-charts has **no** pie/donut type), keeping the slice order largest green → coral → amber (§1).
  - **Time axis (monthly / periodic series) → real calendar dates, never a bare index.** A time-series chart plotted over months/periods (Auto Loan / Amortization / Mortgage *Balance over time*, Compound Interest growth, any schedule plotted over time) labels its **time-axis ticks AND the crosshair/hover readout** as a real calendar **`Mon YYYY`** (e.g. *Mar 2027*) — derived from a **start date** (default = the current month, or the series/loan start if the calculator has one) and stepped one month per period — **never** a raw month **number** (`1, 2, 3…`). lightweight-charts' time scale takes real dates natively; map period *n* → start-date + *n* months. (iteration-0007 review: Auto Loan's *Balance Over Time* showed bare month numbers, unreadable as a real timeline.) Standing convention — apply to every time-series chart and every regen.
  - **Data source:** charts read from the **§4 JSON envelope** — all math stays server-side (§0.5); the chart only renders values the backend already computed.
  - **No-JS fallback (always retained):** the underlying data is always reachable without JS — a **data table or text legend** — so a chart enhances the numbers, never gates access to them.
  - **Not colour alone (§6):** slices/series must be distinguishable beyond hue (a label, the hover tooltip, the fallback table) — never lean on colour to convey which slice is which.
  - **Packaging (importmap, no build step):** the library must be a **self-contained single-file ESM bundle**, or **vendored under `vendor/javascript`** — a split-chunk dist build (entry imports sub-chunks) 404s at runtime under importmap. Known-good: `lightweight-charts` (vendored) and `chart.js` pinned to the self-contained `chart.js/auto` bundle (vendored). (Operationalized in `.claude/agents/frontend.md`.)
  - **Proven to paint (mandatory test):** every chart ships a **pixel-level system-test assertion** — sample the canvas and require a minimum count of non-transparent pixels — so a blank canvas is a **hard CI failure**, not just a visual-gate catch (markup assertions can't see a blank canvas). (Operationalized in `.claude/agents/frontend.md`.)
- **Data table** — thin `rule` borders, right-aligned `tabular-nums`, a hard total row (top border `ink`). Tag every data table `.data-table` and wrap it in `.table-scroll`.
  - **Numeric / money / range cells never wrap mid-value (single-line).** A numeric, money, or **range** cell stays on **one line** — a bracket range like `$103,350 – $197,300` must **not** split across two lines mid-range (the Income Tax bracket-breakdown failure the iteration-0007 harvest fixed). This is enforced at the **shared component, not per page**, so it propagates to every calculator's tables (bracket breakdowns, amortization / auto-loan / mortgage / loan / personal-loan / compound-interest schedules, the discount/sales-tax/tip/VAT breakdowns) and survives the regen sweep: tag the table **`.data-table`**, and the shared CSS forces `white-space: nowrap` on any `tabular-nums` cell — *and* any `tabular-nums` element **nested** in a cell, e.g. the range `<code class="tabular-nums">`. (Deliberately scoped to table cells: it does **not** touch the stat-card `<dd>` — also `tabular-nums` — whose `overflow-wrap` never-clip net must keep wrapping; those aren't table cells, so the selector skips them.)
  - **Narrow viewport → scroll, never clip (§6).** Because nowrap cells can make a wide table exceed a narrow result panel, **wrap every data table in the `.table-scroll` container** (`overflow-x-auto`): a table wider than its panel **scrolls horizontally** rather than overflowing or clipping, so a single value is never split *and* never lost. A long schedule's vertical-scroll wrapper composes with this (the wrapper carries both `overflow-x-auto overflow-y-auto`). This is the no-JS, no-clip baseline.

---

## 5. Tailwind mapping & the token guardrail

Styling is **Tailwind CSS v4** utilities written in ERB. The tokens above are declared once in `app/assets/tailwind/application.css` under `@theme`, e.g.:

```css
@import "tailwindcss";

@theme {
  --color-bg:           #fdf8f3;
  --color-surface:      #ffffff;
  --color-ink:          #241d18;
  --color-muted:        #6f6155;
  --color-label:        #8a7768;
  --color-faint:        #a08a7c;
  --color-primary:      #ef6c4d;
  --color-accent:       #2f9e6f;
  --color-amber:        #ffb703;
  --color-border:       #f3ebe2;
  --color-border-input: #ece1d6;
  --color-rule:         #efe4d8;
  --font-sans:          "Inter", "Helvetica Neue", system-ui, sans-serif;
}
```

These generate utilities (`bg-bg`, `text-ink`, `border-border-input`, `font-sans`, …). Set the page defaults (`bg-bg`, `text-ink`, `font-sans`) on `<body>`.

### ⚠️ The token guardrail (load-bearing)

**Prefer `@theme` tokens. Treat an arbitrary value — `text-[#ef6c4d]`, `mt-[37px]`, `w-[437px]` — as a smell that must be justified.** Tailwind's leverage for an *agent-authored* codebase is consistency-by-default; arbitrary `[...]` values quietly erode the design system across 191 pages. Rules:

- **Color:** never hard-code a hex in markup. Use a token utility. If a needed color isn't a token, **add it to `@theme`** (and to §1) rather than inlining it.
- **Type/spacing:** use the standard scale. Reach for an arbitrary value only when the standard scale genuinely can't express it, and leave a one-line comment saying why.
- **Repetition:** when a utility cluster repeats **≥3×**, extract a partial (preferred) or a small `@apply` component class — don't copy-paste utility soup.

This guardrail is the price of keeping Tailwind's speed *and* the design system's discipline.

---

## 6. Accessibility & responsive (requirements)

- Semantic HTML (`<nav>`, `<main>`, `<table>`, real headings); a `<label>` for **every** input.
- Visible focus states (focus → `accent`); keyboard-operable.
- **WCAG AA** contrast on all text (verify coral/green on cream).
- **Mobile-first**; the two-column layout collapses to one; data tables scroll or reflow rather than overflow.

---

## 7. The seam (what the UI codes against)

The UI renders the **JSON envelope** defined in `ARCHITECTURE.md §4` (`{ ok, calculator, inputs, result | errors }`) and the tokens/components here — **nothing else**. How a calculator form submits to the JSON endpoint (full request vs. Turbo vs. fetch) is settled jointly with the backend agent when the first calculator is built; until then, plain server-rendered forms (e.g. login) are the baseline.
