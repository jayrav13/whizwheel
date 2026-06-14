# Per-calculator helper for Amortization (issue #84; split per issue #107). Holds the
# field-label map (single source of truth, DESIGN.md §4) and the chart-derivation helpers
# (donut series + conic gradient + chart payload, and the balance-curve points). The FE
# does no math beyond mapping the backend's computed figures into display proportions
# (ARCHITECTURE.md §4). Auto-included into views; slug `amortization` →
# Calculators::AmortizationHelper::FIELD_LABELS.
module Calculators
  module AmortizationHelper
    # The visible label for each Amortization input.
    FIELD_LABELS = {
      "principal"   => "Loan amount",
      "annual_rate" => "Annual interest rate",
      "years"       => "Loan term"
    }.freeze

    # The donut series for the Amortization result (DESIGN.md §4 "Charts"). The donut
    # compares principal vs. total interest. Returns each slice with its share (0–100, for
    # the conic stops) and which token paints it — the LARGER slice gets accent green per
    # DESIGN.md, the smaller gets coral. The backend owns the figures; this only derives
    # display proportions.
    def amortization_donut(chart)
      principal = BigDecimal(chart[:principal])
      interest  = BigDecimal(chart[:total_interest])
      total     = principal + interest
      # total is always > 0 here (principal validates greater_than 0).
      p_pct = (principal / total * 100).to_f
      i_pct = 100.0 - p_pct
      principal_bigger = principal >= interest
      [
        { key: :principal,      label: "Principal",     amount: chart[:principal],      pct: p_pct, color: principal_bigger ? "accent" : "primary" },
        { key: :total_interest, label: "Total interest", amount: chart[:total_interest], pct: i_pct, color: principal_bigger ? "primary" : "accent" }
      ]
    end

    # The conic-gradient value for the donut: the first slice fills 0→p_pct, the second
    # fills the remainder. Returns a ready-to-use `conic-gradient(...)` string composed of
    # the two token colours so the chart needs no inline hex (DESIGN.md §5 guardrail —
    # the colours come from CSS custom properties the @theme tokens define).
    def amortization_donut_gradient(slices)
      first = slices.first
      stop = first[:pct].round(4)
      "conic-gradient(var(--color-#{first[:color]}) 0 #{stop}%, var(--color-#{slices.last[:color]}) #{stop}% 100%)"
    end

    # The donut series as the flat object the Stimulus chart controller reads from a data
    # attribute (DESIGN.md §4 "Charts" — the Chart.js doughnut). It carries each slice's
    # numeric amount, its visible label, and which token paints it (the colour decision —
    # larger slice green, smaller coral — already made in `amortization_donut`, so the JS
    # never re-derives it). Amounts are the backend's money strings as plain numbers (no
    # delimiters) so Chart.js can size the arcs; the FE does no math (ARCHITECTURE.md §4).
    def amortization_donut_data(slices)
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

    # The balance-over-time curve as SVG polyline/area points in a unit viewBox
    # (0..100 × 0..100), derived from the backend's `balance_curve` samples (month →
    # remaining balance). The FE does no math beyond mapping the supplied points into the
    # plot box: x by month over the term, y by balance over the starting principal
    # (inverted so a falling balance descends). Returns "x,y x,y …" for the points attr.
    def amortization_curve_points(curve)
      max_month   = curve.last[:month].to_f
      max_balance = curve.first[:balance].to_f # month 0 = starting principal, the peak
      max_month = 1.0 if max_month.zero?       # single-point guard (never in practice)
      max_balance = 1.0 if max_balance.zero?
      curve.map do |point|
        x = point[:month].to_f / max_month * 100
        y = 100 - (point[:balance].to_f / max_balance * 100)
        "#{x.round(3)},#{y.round(3)}"
      end.join(" ")
    end
  end
end
