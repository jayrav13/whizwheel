# Per-calculator helper for the Personal Loan calculator (spec issue #256; split per issue
# #107). Holds the field-label map (single source of truth for error phrasing, DESIGN.md §4)
# and the chart-derivation helpers (the principal-vs-interest donut and the balance-over-time
# curve) the result partial reads. Auto-included into views; slug `personal_loan` →
# Calculators::PersonalLoanHelper::FIELD_LABELS in field_labels_for.
#
# Personal Loan is the single-mode loan-core skin: no mode picker, always solving for the
# monthly payment. Its envelope (ARCHITECTURE.md §4) carries the loan totals + the full
# month-by-month schedule, but NO pre-computed chart series — so the two charts are derived
# here from figures the backend already computed. The FE does NO math beyond mapping those
# figures into display proportions (the share of the donut, the y-position on the curve);
# every dollar amount is the backend's, rendered verbatim.
module Calculators
  module PersonalLoanHelper
    # The visible label for each Personal Loan input — what the error phrasing reads back
    # (DESIGN.md §4: "phrase each message against the field's visible label").
    FIELD_LABELS = {
      "loan_amount" => "Loan amount",
      "annual_rate" => "Annual interest rate",
      "term_months" => "Loan term"
    }.freeze

    # The donut series for the Personal Loan result (DESIGN.md §4 "Charts"): the breakdown of
    # the total paid into the principal (the loan amount) and the total interest. Returns each
    # slice with its share (0–100, for the conic stops) and which token paints it — the LARGER
    # slice gets accent green per DESIGN.md §1, the smaller gets coral. The backend owns the
    # figures; this only derives display proportions from the result's money strings.
    def personal_loan_donut(result)
      principal = BigDecimal(result[:loan_amount])
      interest  = BigDecimal(result[:total_interest])
      total     = principal + interest
      # total is always > 0 here (loan_amount validates greater_than 0).
      p_pct = (principal / total * 100).to_f
      i_pct = 100.0 - p_pct
      principal_bigger = principal >= interest
      [
        { key: :principal,      label: "Principal",      amount: result[:loan_amount],    pct: p_pct, color: principal_bigger ? "accent" : "primary" },
        { key: :total_interest, label: "Total interest", amount: result[:total_interest], pct: i_pct, color: principal_bigger ? "primary" : "accent" }
      ]
    end

    # The conic-gradient value for the no-JS fallback donut: the first slice fills 0→p_pct, the
    # second fills the remainder. Returns a ready-to-use `conic-gradient(...)` string composed
    # of the two token colours so the chart needs no inline hex (DESIGN.md §5 guardrail — the
    # colours come from the CSS custom properties the @theme tokens define).
    def personal_loan_donut_gradient(slices)
      first = slices.first
      stop = first[:pct].round(4)
      "conic-gradient(var(--color-#{first[:color]}) 0 #{stop}%, var(--color-#{slices.last[:color]}) #{stop}% 100%)"
    end

    # The donut series as the flat object the Stimulus chart controller reads from a data
    # attribute (DESIGN.md §4 "Charts" — the Chart.js doughnut). It carries each slice's numeric
    # amount, its visible label, and which token paints it (the colour decision — larger slice
    # green, smaller coral — already made in `personal_loan_donut`, so the JS never re-derives
    # it). Amounts are the backend's money strings as plain numbers (no delimiters) so Chart.js
    # can size the arcs; the FE does no math (ARCHITECTURE.md §4).
    def personal_loan_donut_data(slices)
      principal, interest = slices
      {
        principal:      principal[:amount],
        principalLabel: principal[:label],
        principalColor: principal[:color],
        interest:       interest[:amount],
        interestLabel:  interest[:label],
        interestColor:  interest[:color]
      }
    end

    # The balance-over-time curve, derived from the schedule for both charts' data sources.
    # Returns an ordered list of { month, balance } samples — the starting principal at month 0
    # plus the remaining balance after each scheduled payment. Down-sampled for long schedules
    # so the chart carries roughly one point per month for short loans and ≈monthly-to-yearly
    # density for long ones (keeps the series light without distorting the curve — the first and
    # last points are always kept so the curve spans full start→0). The balances are the
    # backend's money strings, passed through verbatim; the FE only selects which rows to plot.
    def personal_loan_balance_curve(result)
      schedule = result[:schedule]
      step = [ (schedule.length / 60.0).ceil, 1 ].max
      curve = [ { month: 0, balance: result[:loan_amount] } ]
      schedule.each_with_index do |row, i|
        next unless ((i + 1) % step).zero? || i == schedule.length - 1
        curve << { month: row[:month], balance: row[:balance] }
      end
      curve
    end

    # The balance-over-time curve as SVG polyline/area points in a unit viewBox (0..100 ×
    # 0..100), for the no-JS fallback. The FE does no math beyond mapping the supplied points
    # into the plot box: x by month over the term, y by balance over the starting principal
    # (inverted so a falling balance descends). Returns "x,y x,y …" for the points attr.
    def personal_loan_curve_points(curve)
      max_month   = curve.last[:month].to_f
      max_balance = BigDecimal(curve.first[:balance]) # month 0 = starting principal, the peak
      max_month = 1.0 if max_month.zero?              # single-point guard (never in practice)
      max_balance = BigDecimal(1) if max_balance.zero?
      curve.map do |point|
        x = point[:month].to_f / max_month * 100
        y = 100 - (BigDecimal(point[:balance]) / max_balance * 100).to_f
        "#{x.round(3)},#{y.round(3)}"
      end.join(" ")
    end
  end
end
