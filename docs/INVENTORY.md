# Calculator Inventory

The full catalog of calculators on [calculator.net](https://www.calculator.net),
maintained idempotently by the PM agent. Re-running a refresh updates this table in
place: new calculators are added, removed ones are marked, and **manually/empirically
authored or corrected data is preserved** — namely **Complexity**, **Tags**,
**Description**, and **Slug** (not clobbered by fresh hypotheses or a re-render). Only the
**derived** columns (Source, Built (PRs)) are recomputed on each refresh.

The catalog has eight columns: `Calculator | Slug | Category | Complexity | Tags |
Description | Source | Built (PRs)`. **Slug** is our **routing slug** —
`Calculators::X.slug` (the class name demodulized + underscored, e.g. `ohms_law`), which is
the key the DB registry ingest joins on (it must match `Base.lookup`). It is **distinct from
Source** (the calculator.net page slug): the calculator.net page for Ohm's Law is
`ohms-law-calculator` while our routing slug is `ohms_law`. Slug is **manually authored** and
**preserved across refreshes**, filled in when a calculator is built (matching its
`app/calculators/<slug>.rb` filename) and left blank for not-yet-built calculators.
**Description** is a concise one-line, manually-authored blurb per
calculator — the catalog cards (and the DB registry that ingests from this file, see
`CLAUDE.md` → "The calculator registry") render it; it is **preserved across refreshes**,
never regenerated, and left blank for not-yet-built calculators (filled in as they ship).
**Source** renders as a markdown link whose display text is the page slug
(the URL filename with `.html` stripped) linking to the full calculator.net URL.
**Built (PRs)** is **derived from live GitHub state** on every refresh — for each
calculator it lists the most recent **merged** PR per layer that closed its `backend` /
`frontend` issue (`BE #N · FE #M`), or is blank when no build PR has merged yet, so the
column doubles as the build-coverage view. **Sort order is completed-first:** every row
with a non-blank Built (PRs) cell floats to the top, then the pending (blank) rows below.
The **completed block** is ordered by **backend completion PR # ascending** (earliest-built
first — a chronological ship history); the **pending block** stays alphabetical by Category,
then Calculator.

## Complexity scale (1–5)

| Rating | Meaning |
|---|---|
| 1 | Trivial — one input to one output, no real formula. |
| 2 | Basic single formula (e.g. BMI, percentage). |
| 3 | Multiple inputs or selectable modes (e.g. loan payment, body-fat methods). |
| 4 | Iterative or tabular output (e.g. amortization schedule, retirement projection). |
| 5 | Multi-mode + charts + numerical solving (e.g. mortgage with extra payments, scientific). |

Pre-build ratings are **hypotheses**; they get corrected as calculators are actually
built and the logs reveal the truth.

## Tag vocabulary (seed — extensible)

`charts`, `multi-input`, `multi-mode`, `date-math`, `time-math`, `iterative-solve`,
`tabular-output`, `currency`, `unit-conversion`, `statistical`, `randomness`,
`text-output`. Add new tags as calculators warrant; record additions here.

**Additions (this refresh):** `geometry` (shape/area/volume/trig solving),
`encoding` (base/number-system or string encode/decode), `physics` (electrical,
thermodynamic, chemistry formulas), `health` (anthropometric/medical formulas).

## Catalog

| Calculator | Slug | Category | Complexity | Tags | Description | Source | Built (PRs) |
|---|---|---|---|---|---|---|---|
| Simple Interest Calculator | simple_interest | Financial | 2 | multi-input | Interest on the original principal only — never compounded. Enter a principal, rate, and term in years or months. | [simple-interest-calculator](https://www.calculator.net/simple-interest-calculator.html) | BE [#89](https://github.com/jayrav13/whizwheel/pull/89) · FE [#138](https://github.com/jayrav13/whizwheel/pull/138) |
| Mean, Median, Mode, Range Calculator | mean_median_mode_range | Math | 3 | statistical, text-output | The central tendency and spread of a list of numbers — mean, median, mode, range, sum, count and more. | [mean-median-mode-range-calculator](https://www.calculator.net/mean-median-mode-range-calculator.html) | BE [#90](https://github.com/jayrav13/whizwheel/pull/90) · FE [#139](https://github.com/jayrav13/whizwheel/pull/139) |
| Tip Calculator | tip | Other | 2 | multi-input | The tip and grand total on a bill, split evenly across your party for the per-person amount. | [tip-calculator](https://www.calculator.net/tip-calculator.html) | BE [#91](https://github.com/jayrav13/whizwheel/pull/91) · FE [#133](https://github.com/jayrav13/whizwheel/pull/133) |
| BMI Calculator | bmi | Fitness & Health | 2 | multi-input, health, unit-conversion | Body Mass Index from weight and height, in US or metric units, with the WHO classification band. | [bmi-calculator](https://www.calculator.net/bmi-calculator.html) | BE [#92](https://github.com/jayrav13/whizwheel/pull/92) · FE [#135](https://github.com/jayrav13/whizwheel/pull/135) |
| Percentage Calculator | percentage | Math | 3 | multi-mode, multi-input | Five percentage operations — % of a number, what percent, percent of what, difference, and increase/decrease. | [percent-calculator](https://www.calculator.net/percent-calculator.html) | BE [#94](https://github.com/jayrav13/whizwheel/pull/94) · FE [#136](https://github.com/jayrav13/whizwheel/pull/136) |
| Age Calculator | age | Other | 3 | date-math, multi-mode | Your exact age between two dates — years, months and days, plus total months, weeks, days and hours. | [age-calculator](https://www.calculator.net/age-calculator.html) | BE [#95](https://github.com/jayrav13/whizwheel/pull/95) · FE [#137](https://github.com/jayrav13/whizwheel/pull/137) |
| Ohms Law Calculator | ohms_law | Other | 2 | multi-input, multi-mode, physics | Voltage, current, resistance, and power — supply any two and solve the other two. | [ohms-law-calculator](https://www.calculator.net/ohms-law-calculator.html) | BE [#96](https://github.com/jayrav13/whizwheel/pull/96) · FE [#134](https://github.com/jayrav13/whizwheel/pull/134) |
| Amortization Calculator | amortization | Financial | 4 | multi-input, tabular-output, charts | The monthly payment on a fixed-rate loan, with the total interest, a principal-vs-interest breakdown, and the full schedule. | [amortization-calculator](https://www.calculator.net/amortization-calculator.html) | BE [#97](https://github.com/jayrav13/whizwheel/pull/97) · FE [#141](https://github.com/jayrav13/whizwheel/pull/141) |
| Right Triangle Calculator | right_triangle | Math | 3 | geometry, charts | Solve a right triangle from two known sides — get the third side, both acute angles, area, perimeter, and altitude. | [right-triangle-calculator](https://www.calculator.net/right-triangle-calculator.html) | BE [#196](https://github.com/jayrav13/whizwheel/pull/196) · FE [#211](https://github.com/jayrav13/whizwheel/pull/211) |
| Standard Deviation Calculator | standard_deviation | Math | 3 | statistical, text-output | Standard deviation, variance and mean of a data set — choose population or sample. | [standard-deviation-calculator](https://www.calculator.net/standard-deviation-calculator.html) | BE [#197](https://github.com/jayrav13/whizwheel/pull/197) · FE [#206](https://github.com/jayrav13/whizwheel/pull/206) |
| Date Calculator | date | Other | 3 | date-math, multi-mode | Days between two dates, or add/subtract years, months, weeks and days from a date. | [date-calculator](https://www.calculator.net/date-calculator.html) | BE [#198](https://github.com/jayrav13/whizwheel/pull/198) · FE [#209](https://github.com/jayrav13/whizwheel/pull/209) |
| Compound Interest Calculator | compound_interest | Financial | 4 | multi-input, iterative-solve, charts | Grow a principal with compound interest — pick how often it compounds (annually to daily) and see the future value, total interest, and a growth curve. | [compound-interest-calculator](https://www.calculator.net/compound-interest-calculator.html) | BE [#199](https://github.com/jayrav13/whizwheel/pull/199) · FE [#208](https://github.com/jayrav13/whizwheel/pull/208) |
| Loan Calculator | loan | Financial | 4 | multi-input, multi-mode, tabular-output | An amortized fixed-rate loan — solve for the monthly payment, the loan amount you can afford, or the term, and see the full repayment schedule. | [loan-calculator](https://www.calculator.net/loan-calculator.html) | BE [#201](https://github.com/jayrav13/whizwheel/pull/201) · FE [#207](https://github.com/jayrav13/whizwheel/pull/207) |
| Mortgage Calculator | mortgage | Financial | 5 | multi-input, iterative-solve, tabular-output, charts | A full home mortgage — monthly payment with taxes, insurance and PMI, total interest, and the complete amortization schedule. | [mortgage-calculator](https://www.calculator.net/mortgage-calculator.html) | BE [#203](https://github.com/jayrav13/whizwheel/pull/203) · FE [#210](https://github.com/jayrav13/whizwheel/pull/210) |
| Pythagorean Theorem Calculator | pythagorean_theorem | Math | 2 | geometry, multi-mode | Solve a right triangle's third side with the Pythagorean theorem — give two sides and get the missing one, plus a labeled figure. | [pythagorean-theorem-calculator](https://www.calculator.net/pythagorean-theorem-calculator.html) | BE [#262](https://github.com/jayrav13/whizwheel/pull/262) · FE [#272](https://github.com/jayrav13/whizwheel/pull/272) |
| Discount Calculator | discount | Financial | 2 | multi-input, multi-mode | Apply a discount to a price — percent off or a fixed amount off — and see the final sale price and how much you saved. | [discount-calculator](https://www.calculator.net/discount-calculator.html) | BE [#263](https://github.com/jayrav13/whizwheel/pull/263) · FE [#271](https://github.com/jayrav13/whizwheel/pull/271) |
| VAT Calculator | vat | Financial | 2 | multi-input, multi-mode | Solve a value-added-tax problem from any two of the three figures — net price, VAT rate, or gross price — and get the VAT amount and the missing value. | [vat-calculator](https://www.calculator.net/vat-calculator.html) | BE [#264](https://github.com/jayrav13/whizwheel/pull/264) · FE [#282](https://github.com/jayrav13/whizwheel/pull/282) |
| ROI Calculator | roi | Financial | 2 | multi-input | Return on investment — enter the amount invested and the amount returned (with an optional holding period) to get the total gain, ROI %, and annualized ROI. | [roi-calculator](https://www.calculator.net/roi-calculator.html) | BE [#265](https://github.com/jayrav13/whizwheel/pull/265) · FE [#278](https://github.com/jayrav13/whizwheel/pull/278) |
| Auto Loan Calculator | auto_loan | Financial | 3 | multi-input, tabular-output | An amortized auto loan — fold trade-in, down payment, sales tax and fees into the financed amount and see the monthly payment, total interest, and full repayment schedule. | [auto-loan-calculator](https://www.calculator.net/auto-loan-calculator.html) | BE [#266](https://github.com/jayrav13/whizwheel/pull/266) · FE [#280](https://github.com/jayrav13/whizwheel/pull/280) |
| Sales Tax Calculator | sales_tax | Financial | 2 | multi-input, multi-mode | Solve a sales-tax problem from any two of the three figures — before-tax price, tax rate, or after-tax price — and get the tax amount and the missing value. | [sales-tax-calculator](https://www.calculator.net/sales-tax-calculator.html) | BE [#268](https://github.com/jayrav13/whizwheel/pull/268) · FE [#281](https://github.com/jayrav13/whizwheel/pull/281) |
| Average Return Calculator | average_return | Financial | 3 | multi-input, statistical | Average a series of period returns — get both the simple arithmetic average and the compounded geometric average (the true annualized rate). | [average-return-calculator](https://www.calculator.net/average-return-calculator.html) | BE [#270](https://github.com/jayrav13/whizwheel/pull/270) · FE [#273](https://github.com/jayrav13/whizwheel/pull/273) |
| Income Tax Calculator | income_tax | Financial | 5 | multi-input, tabular-output | US federal income tax on your taxable income — progressive 2025 single-filer brackets, with the per-bracket breakdown plus your effective and marginal rates. | [tax-calculator](https://www.calculator.net/tax-calculator.html) | BE [#274](https://github.com/jayrav13/whizwheel/pull/274) · FE [#283](https://github.com/jayrav13/whizwheel/pull/283) |
| Personal Loan Calculator | personal_loan | Financial | 3 | multi-input, tabular-output | An amortized personal loan — enter the loan amount, rate, and term to see the monthly payment, total interest, total cost, and full repayment schedule. | [personal-loan-calculator](https://www.calculator.net/personal-loan-calculator.html) | BE [#275](https://github.com/jayrav13/whizwheel/pull/275) · FE [#277](https://github.com/jayrav13/whizwheel/pull/277) |
| House Affordability Calculator | house_affordability | Financial | 4 | multi-input | How much house can you afford — from your income, debts, down payment, and DTI limits, get the maximum monthly payment, loan amount, and home price. | [house-affordability-calculator](https://www.calculator.net/house-affordability-calculator.html) | BE [#276](https://github.com/jayrav13/whizwheel/pull/276) · FE [#279](https://github.com/jayrav13/whizwheel/pull/279) |
| 401K Calculator |  | Financial | 4 | multi-input, iterative-solve, tabular-output, charts |  | [401k-calculator](https://www.calculator.net/401k-calculator.html) |  |
| APR Calculator |  | Financial | 3 | multi-input |  | [apr-calculator](https://www.calculator.net/apr-calculator.html) |  |
| Annuity Calculator |  | Financial | 4 | multi-input, iterative-solve, tabular-output |  | [annuity-calculator](https://www.calculator.net/annuity-calculator.html) |  |
| Annuity Payout Calculator |  | Financial | 4 | multi-input, tabular-output |  | [annuity-payout-calculator](https://www.calculator.net/annuity-payout-calculator.html) |  |
| Auto Lease Calculator |  | Financial | 3 | multi-input |  | [auto-lease-calculator](https://www.calculator.net/auto-lease-calculator.html) |  |
| Boat Loan Calculator |  | Financial | 3 | multi-input |  | [boat-loan-calculator](https://www.calculator.net/boat-loan-calculator.html) |  |
| Bond Calculator |  | Financial | 4 | multi-input, iterative-solve |  | [bond-calculator](https://www.calculator.net/bond-calculator.html) |  |
| Budget Calculator |  | Financial | 3 | multi-input, charts |  | [budget-calculator](https://www.calculator.net/budget-calculator.html) |  |
| Business Loan Calculator |  | Financial | 3 | multi-input, tabular-output |  | [business-loan-calculator](https://www.calculator.net/business-loan-calculator.html) |  |
| CD Calculator |  | Financial | 3 | multi-input |  | [cd-calculator](https://www.calculator.net/cd-calculator.html) |  |
| Cash Back or Low Interest Calculator |  | Financial | 3 | multi-input, multi-mode |  | [cash-back-or-low-interest-calculator](https://www.calculator.net/cash-back-or-low-interest-calculator.html) |  |
| College Cost Calculator |  | Financial | 4 | multi-input, tabular-output, charts |  | [college-cost-calculator](https://www.calculator.net/college-cost-calculator.html) |  |
| Commission Calculator |  | Financial | 2 | multi-input |  | [commission-calculator](https://www.calculator.net/commission-calculator.html) |  |
| Credit Card Calculator |  | Financial | 4 | multi-input, tabular-output |  | [credit-card-calculator](https://www.calculator.net/credit-card-calculator.html) |  |
| Credit Cards Payoff Calculator |  | Financial | 4 | multi-input, tabular-output |  | [credit-card-payoff-calculator](https://www.calculator.net/credit-card-payoff-calculator.html) |  |
| Currency Calculator |  | Financial | 2 | currency, unit-conversion |  | [currency-calculator](https://www.calculator.net/currency-calculator.html) |  |
| Debt Consolidation Calculator |  | Financial | 3 | multi-input, tabular-output |  | [debt-consolidation-calculator](https://www.calculator.net/debt-consolidation-calculator.html) |  |
| Debt Payoff Calculator |  | Financial | 4 | multi-input, tabular-output |  | [debt-payoff-calculator](https://www.calculator.net/debt-payoff-calculator.html) |  |
| Debt-to-Income Ratio Calculator |  | Financial | 2 | multi-input |  | [debt-ratio-calculator](https://www.calculator.net/debt-ratio-calculator.html) |  |
| Depreciation Calculator |  | Financial | 4 | multi-input, multi-mode, tabular-output |  | [depreciation-calculator](https://www.calculator.net/depreciation-calculator.html) |  |
| Down Payment Calculator |  | Financial | 3 | multi-input |  | [down-payment-calculator](https://www.calculator.net/down-payment-calculator.html) |  |
| Estate Tax Calculator |  | Financial | 3 | multi-input |  | [estate-tax-calculator](https://www.calculator.net/estate-tax-calculator.html) |  |
| FHA Loan Calculator |  | Financial | 4 | multi-input, tabular-output |  | [fha-loan-calculator](https://www.calculator.net/fha-loan-calculator.html) |  |
| Finance Calculator |  | Financial | 5 | multi-input, multi-mode, iterative-solve |  | [finance-calculator](https://www.calculator.net/finance-calculator.html) |  |
| Future Value Calculator |  | Financial | 3 | multi-input |  | [future-value-calculator](https://www.calculator.net/future-value-calculator.html) |  |
| HELOC Calculator |  | Financial | 3 | multi-input |  | [heloc-calculator](https://www.calculator.net/heloc-calculator.html) |  |
| Home Equity Loan Calculator |  | Financial | 3 | multi-input, tabular-output |  | [home-equity-loan-calculator](https://www.calculator.net/home-equity-loan-calculator.html) |  |
| IRA Calculator |  | Financial | 4 | multi-input, tabular-output, charts |  | [ira-calculator](https://www.calculator.net/ira-calculator.html) |  |
| IRR Calculator |  | Financial | 4 | multi-input, iterative-solve |  | [irr-calculator](https://www.calculator.net/irr-calculator.html) |  |
| Inflation Calculator |  | Financial | 3 | multi-input, charts |  | [inflation-calculator](https://www.calculator.net/inflation-calculator.html) |  |
| Interest Calculator |  | Financial | 4 | multi-input, tabular-output, charts |  | [interest-calculator](https://www.calculator.net/interest-calculator.html) |  |
| Interest Rate Calculator |  | Financial | 3 | multi-input, iterative-solve |  | [interest-rate-calculator](https://www.calculator.net/interest-rate-calculator.html) |  |
| Investment Calculator |  | Financial | 5 | multi-input, multi-mode, iterative-solve, charts |  | [investment-calculator](https://www.calculator.net/investment-calculator.html) |  |
| Lease Calculator |  | Financial | 3 | multi-input |  | [lease-calculator](https://www.calculator.net/lease-calculator.html) |  |
| Margin Calculator |  | Financial | 2 | multi-input |  | [margin-calculator](https://www.calculator.net/margin-calculator.html) |  |
| Marriage Tax Calculator |  | Financial | 4 | multi-input, multi-mode |  | [marriage-calculator](https://www.calculator.net/marriage-calculator.html) |  |
| Mortgage Payoff Calculator |  | Financial | 4 | multi-input, tabular-output |  | [mortgage-payoff-calculator](https://www.calculator.net/mortgage-payoff-calculator.html) |  |
| Mutual Fund Calculator |  | Financial | 3 | multi-input |  | [mutual-fund-calculator](https://www.calculator.net/mutual-fund-calculator.html) |  |
| Payback Period Calculator |  | Financial | 3 | multi-input |  | [payback-period-calculator](https://www.calculator.net/payback-period-calculator.html) |  |
| Payment Calculator |  | Financial | 4 | multi-input, multi-mode, tabular-output |  | [payment-calculator](https://www.calculator.net/payment-calculator.html) |  |
| Pension Calculator |  | Financial | 4 | multi-input, multi-mode |  | [pension-calculator](https://www.calculator.net/pension-calculator.html) |  |
| Present Value Calculator |  | Financial | 3 | multi-input |  | [present-value-calculator](https://www.calculator.net/present-value-calculator.html) |  |
| RMD Calculator |  | Financial | 3 | multi-input, tabular-output |  | [rmd-calculator](https://www.calculator.net/rmd-calculator.html) |  |
| Real Estate Calculator |  | Financial | 4 | multi-input, multi-mode |  | [real-estate-calculator](https://www.calculator.net/real-estate-calculator.html) |  |
| Refinance Calculator |  | Financial | 4 | multi-input, tabular-output |  | [refinance-calculator](https://www.calculator.net/refinance-calculator.html) |  |
| Rent Calculator |  | Financial | 2 | multi-input |  | [rent-calculator](https://www.calculator.net/rent-calculator.html) |  |
| Rent vs. Buy Calculator |  | Financial | 4 | multi-input, multi-mode, tabular-output |  | [rent-vs-buy-calculator](https://www.calculator.net/rent-vs-buy-calculator.html) |  |
| Rental Property Calculator |  | Financial | 4 | multi-input, tabular-output |  | [rental-property-calculator](https://www.calculator.net/rental-property-calculator.html) |  |
| Repayment Calculator |  | Financial | 3 | multi-input, tabular-output |  | [repayment-calculator](https://www.calculator.net/repayment-calculator.html) |  |
| Retirement Calculator |  | Financial | 5 | multi-input, multi-mode, iterative-solve, charts |  | [retirement-calculator](https://www.calculator.net/retirement-calculator.html) |  |
| Roth IRA Calculator |  | Financial | 4 | multi-input, tabular-output, charts |  | [roth-ira-calculator](https://www.calculator.net/roth-ira-calculator.html) |  |
| Salary Calculator |  | Financial | 3 | multi-input, multi-mode |  | [salary-calculator](https://www.calculator.net/salary-calculator.html) |  |
| Savings Calculator |  | Financial | 4 | multi-input, tabular-output, charts |  | [savings-calculator](https://www.calculator.net/savings-calculator.html) |  |
| Social Security Calculator |  | Financial | 4 | multi-input, multi-mode |  | [social-security-calculator](https://www.calculator.net/social-security-calculator.html) |  |
| Student Loan Calculator |  | Financial | 4 | multi-input, tabular-output |  | [student-loan-calculator](https://www.calculator.net/student-loan-calculator.html) |  |
| Take-Home-Paycheck Calculator |  | Financial | 4 | multi-input, multi-mode |  | [take-home-pay-calculator](https://www.calculator.net/take-home-pay-calculator.html) |  |
| VA Mortgage Calculator |  | Financial | 4 | multi-input, tabular-output |  | [va-mortgage-calculator](https://www.calculator.net/va-mortgage-calculator.html) |  |
| Army Body Fat Calculator |  | Fitness & Health | 3 | multi-input, multi-mode, health |  | [army-body-fat-calculator](https://www.calculator.net/army-body-fat-calculator.html) |  |
| BAC Calculator |  | Fitness & Health | 3 | multi-input, health |  | [bac-calculator](https://www.calculator.net/bac-calculator.html) |  |
| BMR Calculator |  | Fitness & Health | 3 | multi-input, multi-mode, health |  | [bmr-calculator](https://www.calculator.net/bmr-calculator.html) |  |
| Body Fat Calculator |  | Fitness & Health | 3 | multi-input, multi-mode, health |  | [body-fat-calculator](https://www.calculator.net/body-fat-calculator.html) |  |
| Body Surface Area Calculator |  | Fitness & Health | 3 | multi-input, multi-mode, health |  | [body-surface-area-calculator](https://www.calculator.net/body-surface-area-calculator.html) |  |
| Body Type Calculator |  | Fitness & Health | 2 | multi-input, health, text-output |  | [body-type-calculator](https://www.calculator.net/body-type-calculator.html) |  |
| Calorie Calculator |  | Fitness & Health | 3 | multi-input, multi-mode, health |  | [calorie-calculator](https://www.calculator.net/calorie-calculator.html) |  |
| Calories Burned Calculator |  | Fitness & Health | 3 | multi-input, multi-mode, health |  | [calories-burned-calculator](https://www.calculator.net/calories-burned-calculator.html) |  |
| Carbohydrate Calculator |  | Fitness & Health | 3 | multi-input, health |  | [carbohydrate-calculator](https://www.calculator.net/carbohydrate-calculator.html) |  |
| Conception Calculator |  | Fitness & Health | 2 | date-math, health |  | [conception-calculator](https://www.calculator.net/conception-calculator.html) |  |
| Due Date Calculator |  | Fitness & Health | 2 | date-math, health |  | [due-date-calculator](https://www.calculator.net/due-date-calculator.html) |  |
| Fat Intake Calculator |  | Fitness & Health | 3 | multi-input, health |  | [fat-intake-calculator](https://www.calculator.net/fat-intake-calculator.html) |  |
| GFR Calculator |  | Fitness & Health | 3 | multi-input, multi-mode, health |  | [gfr-calculator](https://www.calculator.net/gfr-calculator.html) |  |
| Healthy Weight Calculator |  | Fitness & Health | 3 | multi-input, health |  | [healthy-weight-calculator](https://www.calculator.net/healthy-weight-calculator.html) |  |
| Ideal Weight Calculator |  | Fitness & Health | 3 | multi-input, multi-mode, health |  | [ideal-weight-calculator](https://www.calculator.net/ideal-weight-calculator.html) |  |
| Lean Body Mass Calculator |  | Fitness & Health | 3 | multi-input, multi-mode, health |  | [lean-body-mass-calculator](https://www.calculator.net/lean-body-mass-calculator.html) |  |
| Macro Calculator |  | Fitness & Health | 3 | multi-input, multi-mode, health |  | [macro-calculator](https://www.calculator.net/macro-calculator.html) |  |
| One Rep Max Calculator |  | Fitness & Health | 2 | multi-input, multi-mode |  | [one-rep-max-calculator](https://www.calculator.net/one-rep-max-calculator.html) |  |
| Ovulation Calculator |  | Fitness & Health | 3 | date-math, health, tabular-output |  | [ovulation-calculator](https://www.calculator.net/ovulation-calculator.html) |  |
| Pace Calculator |  | Fitness & Health | 3 | multi-input, multi-mode, time-math, unit-conversion |  | [pace-calculator](https://www.calculator.net/pace-calculator.html) |  |
| Period Calculator |  | Fitness & Health | 3 | date-math, health, tabular-output |  | [period-calculator](https://www.calculator.net/period-calculator.html) |  |
| Pregnancy Calculator |  | Fitness & Health | 3 | date-math, multi-mode, health |  | [pregnancy-calculator](https://www.calculator.net/pregnancy-calculator.html) |  |
| Pregnancy Conception Calculator |  | Fitness & Health | 2 | date-math, health |  | [pregnancy-conception-calculator](https://www.calculator.net/pregnancy-conception-calculator.html) |  |
| Pregnancy Weight Gain Calculator |  | Fitness & Health | 3 | multi-input, health, tabular-output |  | [pregnancy-weight-gain-calculator](https://www.calculator.net/pregnancy-weight-gain-calculator.html) |  |
| Protein Calculator |  | Fitness & Health | 3 | multi-input, health |  | [protein-calculator](https://www.calculator.net/protein-calculator.html) |  |
| TDEE Calculator |  | Fitness & Health | 3 | multi-input, multi-mode, health |  | [tdee-calculator](https://www.calculator.net/tdee-calculator.html) |  |
| Target Heart Rate Calculator |  | Fitness & Health | 3 | multi-input, multi-mode, health |  | [target-heart-rate-calculator](https://www.calculator.net/target-heart-rate-calculator.html) |  |
| Area Calculator |  | Math | 4 | multi-mode, geometry |  | [area-calculator](https://www.calculator.net/area-calculator.html) |  |
| Big Number Calculator |  | Math | 3 | text-output |  | [big-number-calculator](https://www.calculator.net/big-number-calculator.html) |  |
| Binary Calculator |  | Math | 3 | multi-mode, encoding |  | [binary-calculator](https://www.calculator.net/binary-calculator.html) |  |
| Circle Calculator |  | Math | 3 | multi-mode, geometry |  | [circle-calculator](https://www.calculator.net/circle-calculator.html) |  |
| Confidence Interval Calculator |  | Math | 3 | multi-input, statistical |  | [confidence-interval-calculator](https://www.calculator.net/confidence-interval-calculator.html) |  |
| Distance Calculator |  | Math | 3 | multi-mode, geometry |  | [distance-calculator](https://www.calculator.net/distance-calculator.html) |  |
| Exponent Calculator |  | Math | 2 | text-output |  | [exponent-calculator](https://www.calculator.net/exponent-calculator.html) |  |
| Factor Calculator |  | Math | 2 | text-output |  | [factor-calculator](https://www.calculator.net/factor-calculator.html) |  |
| Fraction Calculator |  | Math | 3 | multi-mode, text-output |  | [fraction-calculator](https://www.calculator.net/fraction-calculator.html) |  |
| Greatest Common Factor Calculator |  | Math | 2 | text-output |  | [gcf-calculator](https://www.calculator.net/gcf-calculator.html) |  |
| Half-Life Calculator |  | Math | 3 | multi-input, multi-mode, physics |  | [half-life-calculator](https://www.calculator.net/half-life-calculator.html) |  |
| Hex Calculator |  | Math | 3 | multi-mode, encoding |  | [hex-calculator](https://www.calculator.net/hex-calculator.html) |  |
| Least Common Multiple Calculator |  | Math | 2 | text-output |  | [lcm-calculator](https://www.calculator.net/lcm-calculator.html) |  |
| Log Calculator |  | Math | 2 | text-output |  | [log-calculator](https://www.calculator.net/log-calculator.html) |  |
| Matrix Calculator |  | Math | 4 | multi-mode, multi-input, text-output |  | [matrix-calculator](https://www.calculator.net/matrix-calculator.html) |  |
| Number Sequence Calculator |  | Math | 3 | multi-mode, text-output |  | [number-sequence-calculator](https://www.calculator.net/number-sequence-calculator.html) |  |
| Percent Error Calculator |  | Math | 2 | text-output |  | [percent-error-calculator](https://www.calculator.net/percent-error-calculator.html) |  |
| Permutation and Combination Calculator |  | Math | 3 | statistical, text-output |  | [permutation-and-combination-calculator](https://www.calculator.net/permutation-and-combination-calculator.html) |  |
| Probability Calculator |  | Math | 4 | multi-mode, statistical |  | [probability-calculator](https://www.calculator.net/probability-calculator.html) |  |
| Quadratic Formula Calculator |  | Math | 3 | text-output |  | [quadratic-formula-calculator](https://www.calculator.net/quadratic-formula-calculator.html) |  |
| Random Number Generator |  | Math | 2 | randomness, multi-mode |  | [random-number-generator](https://www.calculator.net/random-number-generator.html) |  |
| Ratio Calculator |  | Math | 2 | multi-mode |  | [ratio-calculator](https://www.calculator.net/ratio-calculator.html) |  |
| Root Calculator |  | Math | 2 | multi-mode, text-output |  | [root-calculator](https://www.calculator.net/root-calculator.html) |  |
| Rounding Calculator |  | Math | 2 | multi-mode |  | [rounding-calculator](https://www.calculator.net/rounding-calculator.html) |  |
| Sample Size Calculator |  | Math | 3 | multi-input, statistical |  | [sample-size-calculator](https://www.calculator.net/sample-size-calculator.html) |  |
| Scientific Calculator |  | Math | 5 | multi-mode, text-output |  | [scientific-calculator](https://www.calculator.net/scientific-calculator.html) |  |
| Scientific Notation Calculator |  | Math | 2 | text-output |  | [scientific-notation-calculator](https://www.calculator.net/scientific-notation-calculator.html) |  |
| Slope Calculator |  | Math | 3 | geometry, charts |  | [slope-calculator](https://www.calculator.net/slope-calculator.html) |  |
| Statistics Calculator |  | Math | 4 | statistical, text-output |  | [statistics-calculator](https://www.calculator.net/statistics-calculator.html) |  |
| Surface Area Calculator |  | Math | 4 | multi-mode, geometry |  | [surface-area-calculator](https://www.calculator.net/surface-area-calculator.html) |  |
| Triangle Calculator |  | Math | 4 | multi-mode, geometry, charts |  | [triangle-calculator](https://www.calculator.net/triangle-calculator.html) |  |
| Volume Calculator |  | Math | 4 | multi-mode, geometry |  | [volume-calculator](https://www.calculator.net/volume-calculator.html) |  |
| Z-score Calculator |  | Math | 3 | statistical, text-output |  | [z-score-calculator](https://www.calculator.net/z-score-calculator.html) |  |
| BTU Calculator |  | Other | 3 | multi-input, physics, unit-conversion |  | [btu-calculator](https://www.calculator.net/btu-calculator.html) |  |
| Bandwidth Calculator |  | Other | 3 | multi-input, multi-mode, unit-conversion |  | [bandwidth-calculator](https://www.calculator.net/bandwidth-calculator.html) |  |
| Base64 Encode / Decode |  | Other | 2 | encoding, text-output |  | [base64-encode-decode](https://www.calculator.net/base64-encode-decode.html) |  |
| Bra Size Calculator |  | Other | 2 | multi-input, unit-conversion |  | [bra-size-calculator](https://www.calculator.net/bra-size-calculator.html) |  |
| Concrete Calculator |  | Other | 4 | multi-mode, multi-input, unit-conversion |  | [concrete-calculator](https://www.calculator.net/concrete-calculator.html) |  |
| Conversion Calculator |  | Other | 3 | multi-mode, unit-conversion |  | [conversion-calculator](https://www.calculator.net/conversion-calculator.html) |  |
| Day Counter |  | Other | 2 | date-math |  | [day-counter](https://www.calculator.net/day-counter.html) |  |
| Day of the Week Calculator |  | Other | 2 | date-math, text-output |  | [day-of-the-week-calculator](https://www.calculator.net/day-of-the-week-calculator.html) |  |
| Density Calculator |  | Other | 2 | multi-input, physics, unit-conversion |  | [density-calculator](https://www.calculator.net/density-calculator.html) |  |
| Dew Point Calculator |  | Other | 2 | multi-input, physics |  | [dew-point-calculator](https://www.calculator.net/dew-point-calculator.html) |  |
| Dice Roller |  | Other | 2 | randomness |  | [dice-roller](https://www.calculator.net/dice-roller.html) |  |
| Electricity Calculator |  | Other | 3 | multi-input, physics |  | [electricity-calculator](https://www.calculator.net/electricity-calculator.html) |  |
| Engine Horsepower Calculator |  | Other | 2 | multi-input, physics |  | [engine-horsepower-calculator](https://www.calculator.net/engine-horsepower-calculator.html) |  |
| Fuel Cost Calculator |  | Other | 2 | multi-input, unit-conversion |  | [fuel-cost-calculator](https://www.calculator.net/fuel-cost-calculator.html) |  |
| GDP Calculator |  | Other | 2 | multi-input |  | [gdp-calculator](https://www.calculator.net/gdp-calculator.html) |  |
| GPA Calculator |  | Other | 3 | multi-input, tabular-output |  | [gpa-calculator](https://www.calculator.net/gpa-calculator.html) |  |
| Gas Mileage Calculator |  | Other | 2 | multi-input, unit-conversion |  | [gas-mileage-calculator](https://www.calculator.net/gas-mileage-calculator.html) |  |
| Golf Handicap Calculator |  | Other | 3 | multi-input, tabular-output |  | [golf-handicap-calculator](https://www.calculator.net/golf-handicap-calculator.html) |  |
| Grade Calculator |  | Other | 3 | multi-input, multi-mode, tabular-output |  | [grade-calculator](https://www.calculator.net/grade-calculator.html) |  |
| Gravel Calculator |  | Other | 3 | multi-input, unit-conversion |  | [gravel-calculator](https://www.calculator.net/gravel-calculator.html) |  |
| Heat Index Calculator |  | Other | 2 | multi-input, physics |  | [heat-index-calculator](https://www.calculator.net/heat-index-calculator.html) |  |
| Height Calculator |  | Other | 2 | multi-input, unit-conversion |  | [height-calculator](https://www.calculator.net/height-calculator.html) |  |
| Horsepower Calculator |  | Other | 2 | multi-input, physics |  | [horsepower-calculator](https://www.calculator.net/horsepower-calculator.html) |  |
| Hours Calculator |  | Other | 2 | time-math |  | [hours-calculator](https://www.calculator.net/hours-calculator.html) |  |
| IP Subnet Calculator |  | Other | 4 | multi-input, encoding, text-output |  | [ip-subnet-calculator](https://www.calculator.net/ip-subnet-calculator.html) |  |
| Love Calculator |  | Other | 1 | text-output, randomness |  | [love-calculator](https://www.calculator.net/love-calculator.html) |  |
| Mass Calculator |  | Other | 2 | multi-input, physics, unit-conversion |  | [mass-calculator](https://www.calculator.net/mass-calculator.html) |  |
| Mileage Calculator |  | Other | 2 | multi-input, unit-conversion |  | [mileage-calculator](https://www.calculator.net/mileage-calculator.html) |  |
| Molarity Calculator |  | Other | 3 | multi-input, physics, unit-conversion |  | [molarity-calculator](https://www.calculator.net/molarity-calculator.html) |  |
| Molecular Weight Calculator |  | Other | 3 | multi-input, physics, text-output |  | [molecular-weight-calculator](https://www.calculator.net/molecular-weight-calculator.html) |  |
| Mulch Calculator |  | Other | 3 | multi-input, unit-conversion |  | [mulch-calculator](https://www.calculator.net/mulch-calculator.html) |  |
| Password Generator |  | Other | 2 | randomness, multi-mode, text-output |  | [password-generator](https://www.calculator.net/password-generator.html) |  |
| Resistor Calculator |  | Other | 3 | multi-mode, encoding, physics |  | [resistor-calculator](https://www.calculator.net/resistor-calculator.html) |  |
| Roman Numeral Converter |  | Other | 2 | encoding, unit-conversion, text-output |  | [roman-numeral-converter](https://www.calculator.net/roman-numeral-converter.html) |  |
| Roofing Calculator |  | Other | 3 | multi-input, unit-conversion |  | [roofing-calculator](https://www.calculator.net/roofing-calculator.html) |  |
| Shoe Size Conversion |  | Other | 2 | unit-conversion, multi-mode |  | [shoe-size-conversion](https://www.calculator.net/shoe-size-conversion.html) |  |
| Sleep Calculator |  | Other | 2 | time-math, multi-mode |  | [sleep-calculator](https://www.calculator.net/sleep-calculator.html) |  |
| Speed Calculator |  | Other | 2 | multi-input, physics, unit-conversion |  | [speed-calculator](https://www.calculator.net/speed-calculator.html) |  |
| Square Footage Calculator |  | Other | 3 | multi-mode, unit-conversion |  | [square-footage-calculator](https://www.calculator.net/square-footage-calculator.html) |  |
| Stair Calculator |  | Other | 3 | multi-input, geometry |  | [stair-calculator](https://www.calculator.net/stair-calculator.html) |  |
| Tile Calculator |  | Other | 3 | multi-input, unit-conversion |  | [tile-calculator](https://www.calculator.net/tile-calculator.html) |  |
| Time Calculator |  | Other | 3 | time-math, multi-mode |  | [time-calculator](https://www.calculator.net/time-calculator.html) |  |
| Time Card Calculator |  | Other | 3 | time-math, multi-input, tabular-output |  | [time-card-calculator](https://www.calculator.net/time-card-calculator.html) |  |
| Time Duration Calculator |  | Other | 2 | time-math, date-math |  | [time-duration-calculator](https://www.calculator.net/time-duration-calculator.html) |  |
| Time Zone Calculator |  | Other | 3 | time-math, date-math, multi-mode |  | [time-zone-calculator](https://www.calculator.net/time-zone-calculator.html) |  |
| Tire Size Calculator |  | Other | 3 | multi-input, multi-mode, unit-conversion |  | [tire-size-calculator](https://www.calculator.net/tire-size-calculator.html) |  |
| URL Encode / Decode |  | Other | 2 | encoding, text-output |  | [url-encode-decode](https://www.calculator.net/url-encode-decode.html) |  |
| Voltage Drop Calculator |  | Other | 3 | multi-input, physics |  | [voltage-drop-calculator](https://www.calculator.net/voltage-drop-calculator.html) |  |
| Weight Calculator |  | Other | 2 | multi-input, unit-conversion |  | [weight-calculator](https://www.calculator.net/weight-calculator.html) |  |
| Wind Chill Calculator |  | Other | 2 | multi-input, physics |  | [wind-chill-calculator](https://www.calculator.net/wind-chill-calculator.html) |  |
