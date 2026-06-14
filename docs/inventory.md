# Calculator Inventory

The full catalog of calculators on [calculator.net](https://www.calculator.net),
maintained idempotently by the PM agent. Re-running a refresh updates this table in
place: new calculators are added, removed ones are marked, and **manually/empirically
corrected complexity and tags are preserved** (not clobbered by fresh hypotheses).

The catalog has six columns: `Calculator | Category | Complexity | Tags | Source |
Built (PRs)`. **Source** renders as a markdown link whose display text is the page slug
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

| Calculator | Category | Complexity | Tags | Source | Built (PRs) |
|---|---|---|---|---|---|
| Percentage Calculator | Math | 3 | multi-mode, multi-input | [percent-calculator](https://www.calculator.net/percent-calculator.html) | BE [#32](https://github.com/jayrav13/whizwheel/pull/32) · FE [#41](https://github.com/jayrav13/whizwheel/pull/41) |
| Ohms Law Calculator | Other | 2 | multi-input, multi-mode, physics | [ohms-law-calculator](https://www.calculator.net/ohms-law-calculator.html) | BE [#57](https://github.com/jayrav13/whizwheel/pull/57) · FE [#60](https://github.com/jayrav13/whizwheel/pull/60) |
| BMI Calculator | Fitness & Health | 2 | multi-input, health, unit-conversion | [bmi-calculator](https://www.calculator.net/bmi-calculator.html) | BE [#58](https://github.com/jayrav13/whizwheel/pull/58) · FE [#62](https://github.com/jayrav13/whizwheel/pull/62) |
| 401K Calculator | Financial | 4 | multi-input, iterative-solve, tabular-output, charts | [401k-calculator](https://www.calculator.net/401k-calculator.html) |  |
| APR Calculator | Financial | 3 | multi-input | [apr-calculator](https://www.calculator.net/apr-calculator.html) |  |
| Amortization Calculator | Financial | 4 | multi-input, tabular-output, charts | [amortization-calculator](https://www.calculator.net/amortization-calculator.html) |  |
| Annuity Calculator | Financial | 4 | multi-input, iterative-solve, tabular-output | [annuity-calculator](https://www.calculator.net/annuity-calculator.html) |  |
| Annuity Payout Calculator | Financial | 4 | multi-input, tabular-output | [annuity-payout-calculator](https://www.calculator.net/annuity-payout-calculator.html) |  |
| Auto Lease Calculator | Financial | 3 | multi-input | [auto-lease-calculator](https://www.calculator.net/auto-lease-calculator.html) |  |
| Auto Loan Calculator | Financial | 3 | multi-input | [auto-loan-calculator](https://www.calculator.net/auto-loan-calculator.html) |  |
| Average Return Calculator | Financial | 3 | multi-input, statistical | [average-return-calculator](https://www.calculator.net/average-return-calculator.html) |  |
| Boat Loan Calculator | Financial | 3 | multi-input | [boat-loan-calculator](https://www.calculator.net/boat-loan-calculator.html) |  |
| Bond Calculator | Financial | 4 | multi-input, iterative-solve | [bond-calculator](https://www.calculator.net/bond-calculator.html) |  |
| Budget Calculator | Financial | 3 | multi-input, charts | [budget-calculator](https://www.calculator.net/budget-calculator.html) |  |
| Business Loan Calculator | Financial | 3 | multi-input, tabular-output | [business-loan-calculator](https://www.calculator.net/business-loan-calculator.html) |  |
| CD Calculator | Financial | 3 | multi-input | [cd-calculator](https://www.calculator.net/cd-calculator.html) |  |
| Cash Back or Low Interest Calculator | Financial | 3 | multi-input, multi-mode | [cash-back-or-low-interest-calculator](https://www.calculator.net/cash-back-or-low-interest-calculator.html) |  |
| College Cost Calculator | Financial | 4 | multi-input, tabular-output, charts | [college-cost-calculator](https://www.calculator.net/college-cost-calculator.html) |  |
| Commission Calculator | Financial | 2 | multi-input | [commission-calculator](https://www.calculator.net/commission-calculator.html) |  |
| Compound Interest Calculator | Financial | 4 | multi-input, iterative-solve, charts | [compound-interest-calculator](https://www.calculator.net/compound-interest-calculator.html) |  |
| Credit Card Calculator | Financial | 4 | multi-input, tabular-output | [credit-card-calculator](https://www.calculator.net/credit-card-calculator.html) |  |
| Credit Cards Payoff Calculator | Financial | 4 | multi-input, tabular-output | [credit-card-payoff-calculator](https://www.calculator.net/credit-card-payoff-calculator.html) |  |
| Currency Calculator | Financial | 2 | currency, unit-conversion | [currency-calculator](https://www.calculator.net/currency-calculator.html) |  |
| Debt Consolidation Calculator | Financial | 3 | multi-input, tabular-output | [debt-consolidation-calculator](https://www.calculator.net/debt-consolidation-calculator.html) |  |
| Debt Payoff Calculator | Financial | 4 | multi-input, tabular-output | [debt-payoff-calculator](https://www.calculator.net/debt-payoff-calculator.html) |  |
| Debt-to-Income Ratio Calculator | Financial | 2 | multi-input | [debt-ratio-calculator](https://www.calculator.net/debt-ratio-calculator.html) |  |
| Depreciation Calculator | Financial | 4 | multi-input, multi-mode, tabular-output | [depreciation-calculator](https://www.calculator.net/depreciation-calculator.html) |  |
| Discount Calculator | Financial | 2 | multi-input | [discount-calculator](https://www.calculator.net/discount-calculator.html) |  |
| Down Payment Calculator | Financial | 3 | multi-input | [down-payment-calculator](https://www.calculator.net/down-payment-calculator.html) |  |
| Estate Tax Calculator | Financial | 3 | multi-input | [estate-tax-calculator](https://www.calculator.net/estate-tax-calculator.html) |  |
| FHA Loan Calculator | Financial | 4 | multi-input, tabular-output | [fha-loan-calculator](https://www.calculator.net/fha-loan-calculator.html) |  |
| Finance Calculator | Financial | 5 | multi-input, multi-mode, iterative-solve | [finance-calculator](https://www.calculator.net/finance-calculator.html) |  |
| Future Value Calculator | Financial | 3 | multi-input | [future-value-calculator](https://www.calculator.net/future-value-calculator.html) |  |
| HELOC Calculator | Financial | 3 | multi-input | [heloc-calculator](https://www.calculator.net/heloc-calculator.html) |  |
| Home Equity Loan Calculator | Financial | 3 | multi-input, tabular-output | [home-equity-loan-calculator](https://www.calculator.net/home-equity-loan-calculator.html) |  |
| House Affordability Calculator | Financial | 4 | multi-input | [house-affordability-calculator](https://www.calculator.net/house-affordability-calculator.html) |  |
| IRA Calculator | Financial | 4 | multi-input, tabular-output, charts | [ira-calculator](https://www.calculator.net/ira-calculator.html) |  |
| IRR Calculator | Financial | 4 | multi-input, iterative-solve | [irr-calculator](https://www.calculator.net/irr-calculator.html) |  |
| Income Tax Calculator | Financial | 5 | multi-input, multi-mode, tabular-output | [tax-calculator](https://www.calculator.net/tax-calculator.html) |  |
| Inflation Calculator | Financial | 3 | multi-input, charts | [inflation-calculator](https://www.calculator.net/inflation-calculator.html) |  |
| Interest Calculator | Financial | 4 | multi-input, tabular-output, charts | [interest-calculator](https://www.calculator.net/interest-calculator.html) |  |
| Interest Rate Calculator | Financial | 3 | multi-input, iterative-solve | [interest-rate-calculator](https://www.calculator.net/interest-rate-calculator.html) |  |
| Investment Calculator | Financial | 5 | multi-input, multi-mode, iterative-solve, charts | [investment-calculator](https://www.calculator.net/investment-calculator.html) |  |
| Lease Calculator | Financial | 3 | multi-input | [lease-calculator](https://www.calculator.net/lease-calculator.html) |  |
| Loan Calculator | Financial | 4 | multi-input, multi-mode, tabular-output | [loan-calculator](https://www.calculator.net/loan-calculator.html) |  |
| Margin Calculator | Financial | 2 | multi-input | [margin-calculator](https://www.calculator.net/margin-calculator.html) |  |
| Marriage Tax Calculator | Financial | 4 | multi-input, multi-mode | [marriage-calculator](https://www.calculator.net/marriage-calculator.html) |  |
| Mortgage Calculator | Financial | 5 | multi-input, iterative-solve, tabular-output, charts | [mortgage-calculator](https://www.calculator.net/mortgage-calculator.html) |  |
| Mortgage Payoff Calculator | Financial | 4 | multi-input, tabular-output | [mortgage-payoff-calculator](https://www.calculator.net/mortgage-payoff-calculator.html) |  |
| Mutual Fund Calculator | Financial | 3 | multi-input | [mutual-fund-calculator](https://www.calculator.net/mutual-fund-calculator.html) |  |
| Payback Period Calculator | Financial | 3 | multi-input | [payback-period-calculator](https://www.calculator.net/payback-period-calculator.html) |  |
| Payment Calculator | Financial | 4 | multi-input, multi-mode, tabular-output | [payment-calculator](https://www.calculator.net/payment-calculator.html) |  |
| Pension Calculator | Financial | 4 | multi-input, multi-mode | [pension-calculator](https://www.calculator.net/pension-calculator.html) |  |
| Personal Loan Calculator | Financial | 3 | multi-input, tabular-output | [personal-loan-calculator](https://www.calculator.net/personal-loan-calculator.html) |  |
| Present Value Calculator | Financial | 3 | multi-input | [present-value-calculator](https://www.calculator.net/present-value-calculator.html) |  |
| RMD Calculator | Financial | 3 | multi-input, tabular-output | [rmd-calculator](https://www.calculator.net/rmd-calculator.html) |  |
| ROI Calculator | Financial | 2 | multi-input | [roi-calculator](https://www.calculator.net/roi-calculator.html) |  |
| Real Estate Calculator | Financial | 4 | multi-input, multi-mode | [real-estate-calculator](https://www.calculator.net/real-estate-calculator.html) |  |
| Refinance Calculator | Financial | 4 | multi-input, tabular-output | [refinance-calculator](https://www.calculator.net/refinance-calculator.html) |  |
| Rent Calculator | Financial | 2 | multi-input | [rent-calculator](https://www.calculator.net/rent-calculator.html) |  |
| Rent vs. Buy Calculator | Financial | 4 | multi-input, multi-mode, tabular-output | [rent-vs-buy-calculator](https://www.calculator.net/rent-vs-buy-calculator.html) |  |
| Rental Property Calculator | Financial | 4 | multi-input, tabular-output | [rental-property-calculator](https://www.calculator.net/rental-property-calculator.html) |  |
| Repayment Calculator | Financial | 3 | multi-input, tabular-output | [repayment-calculator](https://www.calculator.net/repayment-calculator.html) |  |
| Retirement Calculator | Financial | 5 | multi-input, multi-mode, iterative-solve, charts | [retirement-calculator](https://www.calculator.net/retirement-calculator.html) |  |
| Roth IRA Calculator | Financial | 4 | multi-input, tabular-output, charts | [roth-ira-calculator](https://www.calculator.net/roth-ira-calculator.html) |  |
| Salary Calculator | Financial | 3 | multi-input, multi-mode | [salary-calculator](https://www.calculator.net/salary-calculator.html) |  |
| Sales Tax Calculator | Financial | 2 | multi-input | [sales-tax-calculator](https://www.calculator.net/sales-tax-calculator.html) |  |
| Savings Calculator | Financial | 4 | multi-input, tabular-output, charts | [savings-calculator](https://www.calculator.net/savings-calculator.html) |  |
| Simple Interest Calculator | Financial | 2 | multi-input | [simple-interest-calculator](https://www.calculator.net/simple-interest-calculator.html) |  |
| Social Security Calculator | Financial | 4 | multi-input, multi-mode | [social-security-calculator](https://www.calculator.net/social-security-calculator.html) |  |
| Student Loan Calculator | Financial | 4 | multi-input, tabular-output | [student-loan-calculator](https://www.calculator.net/student-loan-calculator.html) |  |
| Take-Home-Paycheck Calculator | Financial | 4 | multi-input, multi-mode | [take-home-pay-calculator](https://www.calculator.net/take-home-pay-calculator.html) |  |
| VA Mortgage Calculator | Financial | 4 | multi-input, tabular-output | [va-mortgage-calculator](https://www.calculator.net/va-mortgage-calculator.html) |  |
| VAT Calculator | Financial | 2 | multi-input | [vat-calculator](https://www.calculator.net/vat-calculator.html) |  |
| Army Body Fat Calculator | Fitness & Health | 3 | multi-input, multi-mode, health | [army-body-fat-calculator](https://www.calculator.net/army-body-fat-calculator.html) |  |
| BAC Calculator | Fitness & Health | 3 | multi-input, health | [bac-calculator](https://www.calculator.net/bac-calculator.html) |  |
| BMR Calculator | Fitness & Health | 3 | multi-input, multi-mode, health | [bmr-calculator](https://www.calculator.net/bmr-calculator.html) |  |
| Body Fat Calculator | Fitness & Health | 3 | multi-input, multi-mode, health | [body-fat-calculator](https://www.calculator.net/body-fat-calculator.html) |  |
| Body Surface Area Calculator | Fitness & Health | 3 | multi-input, multi-mode, health | [body-surface-area-calculator](https://www.calculator.net/body-surface-area-calculator.html) |  |
| Body Type Calculator | Fitness & Health | 2 | multi-input, health, text-output | [body-type-calculator](https://www.calculator.net/body-type-calculator.html) |  |
| Calorie Calculator | Fitness & Health | 3 | multi-input, multi-mode, health | [calorie-calculator](https://www.calculator.net/calorie-calculator.html) |  |
| Calories Burned Calculator | Fitness & Health | 3 | multi-input, multi-mode, health | [calories-burned-calculator](https://www.calculator.net/calories-burned-calculator.html) |  |
| Carbohydrate Calculator | Fitness & Health | 3 | multi-input, health | [carbohydrate-calculator](https://www.calculator.net/carbohydrate-calculator.html) |  |
| Conception Calculator | Fitness & Health | 2 | date-math, health | [conception-calculator](https://www.calculator.net/conception-calculator.html) |  |
| Due Date Calculator | Fitness & Health | 2 | date-math, health | [due-date-calculator](https://www.calculator.net/due-date-calculator.html) |  |
| Fat Intake Calculator | Fitness & Health | 3 | multi-input, health | [fat-intake-calculator](https://www.calculator.net/fat-intake-calculator.html) |  |
| GFR Calculator | Fitness & Health | 3 | multi-input, multi-mode, health | [gfr-calculator](https://www.calculator.net/gfr-calculator.html) |  |
| Healthy Weight Calculator | Fitness & Health | 3 | multi-input, health | [healthy-weight-calculator](https://www.calculator.net/healthy-weight-calculator.html) |  |
| Ideal Weight Calculator | Fitness & Health | 3 | multi-input, multi-mode, health | [ideal-weight-calculator](https://www.calculator.net/ideal-weight-calculator.html) |  |
| Lean Body Mass Calculator | Fitness & Health | 3 | multi-input, multi-mode, health | [lean-body-mass-calculator](https://www.calculator.net/lean-body-mass-calculator.html) |  |
| Macro Calculator | Fitness & Health | 3 | multi-input, multi-mode, health | [macro-calculator](https://www.calculator.net/macro-calculator.html) |  |
| One Rep Max Calculator | Fitness & Health | 2 | multi-input, multi-mode | [one-rep-max-calculator](https://www.calculator.net/one-rep-max-calculator.html) |  |
| Ovulation Calculator | Fitness & Health | 3 | date-math, health, tabular-output | [ovulation-calculator](https://www.calculator.net/ovulation-calculator.html) |  |
| Pace Calculator | Fitness & Health | 3 | multi-input, multi-mode, time-math, unit-conversion | [pace-calculator](https://www.calculator.net/pace-calculator.html) |  |
| Period Calculator | Fitness & Health | 3 | date-math, health, tabular-output | [period-calculator](https://www.calculator.net/period-calculator.html) |  |
| Pregnancy Calculator | Fitness & Health | 3 | date-math, multi-mode, health | [pregnancy-calculator](https://www.calculator.net/pregnancy-calculator.html) |  |
| Pregnancy Conception Calculator | Fitness & Health | 2 | date-math, health | [pregnancy-conception-calculator](https://www.calculator.net/pregnancy-conception-calculator.html) |  |
| Pregnancy Weight Gain Calculator | Fitness & Health | 3 | multi-input, health, tabular-output | [pregnancy-weight-gain-calculator](https://www.calculator.net/pregnancy-weight-gain-calculator.html) |  |
| Protein Calculator | Fitness & Health | 3 | multi-input, health | [protein-calculator](https://www.calculator.net/protein-calculator.html) |  |
| TDEE Calculator | Fitness & Health | 3 | multi-input, multi-mode, health | [tdee-calculator](https://www.calculator.net/tdee-calculator.html) |  |
| Target Heart Rate Calculator | Fitness & Health | 3 | multi-input, multi-mode, health | [target-heart-rate-calculator](https://www.calculator.net/target-heart-rate-calculator.html) |  |
| Area Calculator | Math | 4 | multi-mode, geometry | [area-calculator](https://www.calculator.net/area-calculator.html) |  |
| Big Number Calculator | Math | 3 | text-output | [big-number-calculator](https://www.calculator.net/big-number-calculator.html) |  |
| Binary Calculator | Math | 3 | multi-mode, encoding | [binary-calculator](https://www.calculator.net/binary-calculator.html) |  |
| Circle Calculator | Math | 3 | multi-mode, geometry | [circle-calculator](https://www.calculator.net/circle-calculator.html) |  |
| Confidence Interval Calculator | Math | 3 | multi-input, statistical | [confidence-interval-calculator](https://www.calculator.net/confidence-interval-calculator.html) |  |
| Distance Calculator | Math | 3 | multi-mode, geometry | [distance-calculator](https://www.calculator.net/distance-calculator.html) |  |
| Exponent Calculator | Math | 2 | text-output | [exponent-calculator](https://www.calculator.net/exponent-calculator.html) |  |
| Factor Calculator | Math | 2 | text-output | [factor-calculator](https://www.calculator.net/factor-calculator.html) |  |
| Fraction Calculator | Math | 3 | multi-mode, text-output | [fraction-calculator](https://www.calculator.net/fraction-calculator.html) |  |
| Greatest Common Factor Calculator | Math | 2 | text-output | [gcf-calculator](https://www.calculator.net/gcf-calculator.html) |  |
| Half-Life Calculator | Math | 3 | multi-input, multi-mode, physics | [half-life-calculator](https://www.calculator.net/half-life-calculator.html) |  |
| Hex Calculator | Math | 3 | multi-mode, encoding | [hex-calculator](https://www.calculator.net/hex-calculator.html) |  |
| Least Common Multiple Calculator | Math | 2 | text-output | [lcm-calculator](https://www.calculator.net/lcm-calculator.html) |  |
| Log Calculator | Math | 2 | text-output | [log-calculator](https://www.calculator.net/log-calculator.html) |  |
| Matrix Calculator | Math | 4 | multi-mode, multi-input, text-output | [matrix-calculator](https://www.calculator.net/matrix-calculator.html) |  |
| Mean, Median, Mode, Range Calculator | Math | 3 | statistical, text-output | [mean-median-mode-range-calculator](https://www.calculator.net/mean-median-mode-range-calculator.html) |  |
| Number Sequence Calculator | Math | 3 | multi-mode, text-output | [number-sequence-calculator](https://www.calculator.net/number-sequence-calculator.html) |  |
| Percent Error Calculator | Math | 2 | text-output | [percent-error-calculator](https://www.calculator.net/percent-error-calculator.html) |  |
| Permutation and Combination Calculator | Math | 3 | statistical, text-output | [permutation-and-combination-calculator](https://www.calculator.net/permutation-and-combination-calculator.html) |  |
| Probability Calculator | Math | 4 | multi-mode, statistical | [probability-calculator](https://www.calculator.net/probability-calculator.html) |  |
| Pythagorean Theorem Calculator | Math | 2 | geometry | [pythagorean-theorem-calculator](https://www.calculator.net/pythagorean-theorem-calculator.html) |  |
| Quadratic Formula Calculator | Math | 3 | text-output | [quadratic-formula-calculator](https://www.calculator.net/quadratic-formula-calculator.html) |  |
| Random Number Generator | Math | 2 | randomness, multi-mode | [random-number-generator](https://www.calculator.net/random-number-generator.html) |  |
| Ratio Calculator | Math | 2 | multi-mode | [ratio-calculator](https://www.calculator.net/ratio-calculator.html) |  |
| Right Triangle Calculator | Math | 3 | geometry, charts | [right-triangle-calculator](https://www.calculator.net/right-triangle-calculator.html) |  |
| Root Calculator | Math | 2 | multi-mode, text-output | [root-calculator](https://www.calculator.net/root-calculator.html) |  |
| Rounding Calculator | Math | 2 | multi-mode | [rounding-calculator](https://www.calculator.net/rounding-calculator.html) |  |
| Sample Size Calculator | Math | 3 | multi-input, statistical | [sample-size-calculator](https://www.calculator.net/sample-size-calculator.html) |  |
| Scientific Calculator | Math | 5 | multi-mode, text-output | [scientific-calculator](https://www.calculator.net/scientific-calculator.html) |  |
| Scientific Notation Calculator | Math | 2 | text-output | [scientific-notation-calculator](https://www.calculator.net/scientific-notation-calculator.html) |  |
| Slope Calculator | Math | 3 | geometry, charts | [slope-calculator](https://www.calculator.net/slope-calculator.html) |  |
| Standard Deviation Calculator | Math | 3 | statistical, text-output | [standard-deviation-calculator](https://www.calculator.net/standard-deviation-calculator.html) |  |
| Statistics Calculator | Math | 4 | statistical, text-output | [statistics-calculator](https://www.calculator.net/statistics-calculator.html) |  |
| Surface Area Calculator | Math | 4 | multi-mode, geometry | [surface-area-calculator](https://www.calculator.net/surface-area-calculator.html) |  |
| Triangle Calculator | Math | 4 | multi-mode, geometry, charts | [triangle-calculator](https://www.calculator.net/triangle-calculator.html) |  |
| Volume Calculator | Math | 4 | multi-mode, geometry | [volume-calculator](https://www.calculator.net/volume-calculator.html) |  |
| Z-score Calculator | Math | 3 | statistical, text-output | [z-score-calculator](https://www.calculator.net/z-score-calculator.html) |  |
| Age Calculator | Other | 3 | date-math, multi-mode | [age-calculator](https://www.calculator.net/age-calculator.html) |  |
| BTU Calculator | Other | 3 | multi-input, physics, unit-conversion | [btu-calculator](https://www.calculator.net/btu-calculator.html) |  |
| Bandwidth Calculator | Other | 3 | multi-input, multi-mode, unit-conversion | [bandwidth-calculator](https://www.calculator.net/bandwidth-calculator.html) |  |
| Base64 Encode / Decode | Other | 2 | encoding, text-output | [base64-encode-decode](https://www.calculator.net/base64-encode-decode.html) |  |
| Bra Size Calculator | Other | 2 | multi-input, unit-conversion | [bra-size-calculator](https://www.calculator.net/bra-size-calculator.html) |  |
| Concrete Calculator | Other | 4 | multi-mode, multi-input, unit-conversion | [concrete-calculator](https://www.calculator.net/concrete-calculator.html) |  |
| Conversion Calculator | Other | 3 | multi-mode, unit-conversion | [conversion-calculator](https://www.calculator.net/conversion-calculator.html) |  |
| Date Calculator | Other | 3 | date-math, multi-mode | [date-calculator](https://www.calculator.net/date-calculator.html) |  |
| Day Counter | Other | 2 | date-math | [day-counter](https://www.calculator.net/day-counter.html) |  |
| Day of the Week Calculator | Other | 2 | date-math, text-output | [day-of-the-week-calculator](https://www.calculator.net/day-of-the-week-calculator.html) |  |
| Density Calculator | Other | 2 | multi-input, physics, unit-conversion | [density-calculator](https://www.calculator.net/density-calculator.html) |  |
| Dew Point Calculator | Other | 2 | multi-input, physics | [dew-point-calculator](https://www.calculator.net/dew-point-calculator.html) |  |
| Dice Roller | Other | 2 | randomness | [dice-roller](https://www.calculator.net/dice-roller.html) |  |
| Electricity Calculator | Other | 3 | multi-input, physics | [electricity-calculator](https://www.calculator.net/electricity-calculator.html) |  |
| Engine Horsepower Calculator | Other | 2 | multi-input, physics | [engine-horsepower-calculator](https://www.calculator.net/engine-horsepower-calculator.html) |  |
| Fuel Cost Calculator | Other | 2 | multi-input, unit-conversion | [fuel-cost-calculator](https://www.calculator.net/fuel-cost-calculator.html) |  |
| GDP Calculator | Other | 2 | multi-input | [gdp-calculator](https://www.calculator.net/gdp-calculator.html) |  |
| GPA Calculator | Other | 3 | multi-input, tabular-output | [gpa-calculator](https://www.calculator.net/gpa-calculator.html) |  |
| Gas Mileage Calculator | Other | 2 | multi-input, unit-conversion | [gas-mileage-calculator](https://www.calculator.net/gas-mileage-calculator.html) |  |
| Golf Handicap Calculator | Other | 3 | multi-input, tabular-output | [golf-handicap-calculator](https://www.calculator.net/golf-handicap-calculator.html) |  |
| Grade Calculator | Other | 3 | multi-input, multi-mode, tabular-output | [grade-calculator](https://www.calculator.net/grade-calculator.html) |  |
| Gravel Calculator | Other | 3 | multi-input, unit-conversion | [gravel-calculator](https://www.calculator.net/gravel-calculator.html) |  |
| Heat Index Calculator | Other | 2 | multi-input, physics | [heat-index-calculator](https://www.calculator.net/heat-index-calculator.html) |  |
| Height Calculator | Other | 2 | multi-input, unit-conversion | [height-calculator](https://www.calculator.net/height-calculator.html) |  |
| Horsepower Calculator | Other | 2 | multi-input, physics | [horsepower-calculator](https://www.calculator.net/horsepower-calculator.html) |  |
| Hours Calculator | Other | 2 | time-math | [hours-calculator](https://www.calculator.net/hours-calculator.html) |  |
| IP Subnet Calculator | Other | 4 | multi-input, encoding, text-output | [ip-subnet-calculator](https://www.calculator.net/ip-subnet-calculator.html) |  |
| Love Calculator | Other | 1 | text-output, randomness | [love-calculator](https://www.calculator.net/love-calculator.html) |  |
| Mass Calculator | Other | 2 | multi-input, physics, unit-conversion | [mass-calculator](https://www.calculator.net/mass-calculator.html) |  |
| Mileage Calculator | Other | 2 | multi-input, unit-conversion | [mileage-calculator](https://www.calculator.net/mileage-calculator.html) |  |
| Molarity Calculator | Other | 3 | multi-input, physics, unit-conversion | [molarity-calculator](https://www.calculator.net/molarity-calculator.html) |  |
| Molecular Weight Calculator | Other | 3 | multi-input, physics, text-output | [molecular-weight-calculator](https://www.calculator.net/molecular-weight-calculator.html) |  |
| Mulch Calculator | Other | 3 | multi-input, unit-conversion | [mulch-calculator](https://www.calculator.net/mulch-calculator.html) |  |
| Password Generator | Other | 2 | randomness, multi-mode, text-output | [password-generator](https://www.calculator.net/password-generator.html) |  |
| Resistor Calculator | Other | 3 | multi-mode, encoding, physics | [resistor-calculator](https://www.calculator.net/resistor-calculator.html) |  |
| Roman Numeral Converter | Other | 2 | encoding, unit-conversion, text-output | [roman-numeral-converter](https://www.calculator.net/roman-numeral-converter.html) |  |
| Roofing Calculator | Other | 3 | multi-input, unit-conversion | [roofing-calculator](https://www.calculator.net/roofing-calculator.html) |  |
| Shoe Size Conversion | Other | 2 | unit-conversion, multi-mode | [shoe-size-conversion](https://www.calculator.net/shoe-size-conversion.html) |  |
| Sleep Calculator | Other | 2 | time-math, multi-mode | [sleep-calculator](https://www.calculator.net/sleep-calculator.html) |  |
| Speed Calculator | Other | 2 | multi-input, physics, unit-conversion | [speed-calculator](https://www.calculator.net/speed-calculator.html) |  |
| Square Footage Calculator | Other | 3 | multi-mode, unit-conversion | [square-footage-calculator](https://www.calculator.net/square-footage-calculator.html) |  |
| Stair Calculator | Other | 3 | multi-input, geometry | [stair-calculator](https://www.calculator.net/stair-calculator.html) |  |
| Tile Calculator | Other | 3 | multi-input, unit-conversion | [tile-calculator](https://www.calculator.net/tile-calculator.html) |  |
| Time Calculator | Other | 3 | time-math, multi-mode | [time-calculator](https://www.calculator.net/time-calculator.html) |  |
| Time Card Calculator | Other | 3 | time-math, multi-input, tabular-output | [time-card-calculator](https://www.calculator.net/time-card-calculator.html) |  |
| Time Duration Calculator | Other | 2 | time-math, date-math | [time-duration-calculator](https://www.calculator.net/time-duration-calculator.html) |  |
| Time Zone Calculator | Other | 3 | time-math, date-math, multi-mode | [time-zone-calculator](https://www.calculator.net/time-zone-calculator.html) |  |
| Tip Calculator | Other | 2 | multi-input | [tip-calculator](https://www.calculator.net/tip-calculator.html) |  |
| Tire Size Calculator | Other | 3 | multi-input, multi-mode, unit-conversion | [tire-size-calculator](https://www.calculator.net/tire-size-calculator.html) |  |
| URL Encode / Decode | Other | 2 | encoding, text-output | [url-encode-decode](https://www.calculator.net/url-encode-decode.html) |  |
| Voltage Drop Calculator | Other | 3 | multi-input, physics | [voltage-drop-calculator](https://www.calculator.net/voltage-drop-calculator.html) |  |
| Weight Calculator | Other | 2 | multi-input, unit-conversion | [weight-calculator](https://www.calculator.net/weight-calculator.html) |  |
| Wind Chill Calculator | Other | 2 | multi-input, physics | [wind-chill-calculator](https://www.calculator.net/wind-chill-calculator.html) |  |
