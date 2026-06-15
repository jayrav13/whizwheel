# Per-calculator helper for Mortgage (issue #187; per-calculator split per issue #107).
# Holds the field-label map (single source of truth for error phrasing, DESIGN.md §4) and
# the chart-derivation helpers (the payment-component donut series + conic gradient + the
# flat data payload the Stimulus chart controller reads, and the balance-curve SVG points).
#
# The FE does NO math beyond mapping the backend's already-computed figures into display
# proportions (ARCHITECTURE.md §4 — all math stays server-side). Auto-included into views;
# slug `mortgage` → Calculators::MortgageHelper::FIELD_LABELS.
module Calculators
  module MortgageHelper
    # The visible label for each Mortgage input — the single source of truth for the form
    # labels AND the error-phrasing map (DESIGN.md §4: phrase errors against the visible
    # label, never the raw attribute key).
    FIELD_LABELS = {
      "home_price"            => "Home price",
      "down_payment"          => "Down payment",
      "annual_rate"           => "Annual interest rate",
      "loan_term_years"       => "Loan term",
      "annual_property_tax"   => "Annual property tax",
      "annual_home_insurance" => "Annual home insurance",
      "monthly_hoa"           => "Monthly HOA fee"
    }.freeze

    # The donut palette, in slice order (DESIGN.md §1: largest slice green → coral → amber →
    # a fourth token for the smallest component). The mortgage donut compares the FOUR
    # monthly-payment components (P&I, property tax, home insurance, HOA) — the backend emits
    # them largest-first (P&I always leads), so we paint them in this fixed token order:
    # the leading (largest) slice accent green, then coral, amber, and a quiet label tone.
    DONUT_COLORS = %w[accent primary amber faint].freeze

    # The donut series for the Mortgage result (DESIGN.md §4 "Charts"). The backend's
    # `chart[:payment_components]` is an ordered [{label, amount}] list (P&I, tax, insurance,
    # HOA). We drop zero-amount components (an omitted tax/insurance/HOA contributes nothing
    # to the monthly payment, so it should not draw a slice or clutter the legend), then
    # attach each remaining slice's share of the total (0–100, for the conic stops) and its
    # token colour by position. The backend owns the figures; this only derives display
    # proportions.
    def mortgage_donut(chart)
      components = chart[:payment_components].reject { |c| BigDecimal(c[:amount]).zero? }
      total = components.sum { |c| BigDecimal(c[:amount]) }
      # `total` is the monthly payment, always > 0 (P&I > 0 because the loan amount is > 0).
      components.each_with_index.map do |component, index|
        {
          label: component[:label],
          amount: component[:amount],
          pct: (BigDecimal(component[:amount]) / total * 100).to_f,
          color: DONUT_COLORS[index]
        }
      end
    end

    # The conic-gradient value for the no-JS fallback donut: each slice fills its arc of the
    # ring in order, composed from the slices' token colours so the chart needs no inline hex
    # (DESIGN.md §5 guardrail — the colours come from the @theme CSS custom properties).
    def mortgage_donut_gradient(slices)
      cursor = 0.0
      stops = slices.map do |slice|
        start = cursor.round(4)
        cursor += slice[:pct]
        "var(--color-#{slice[:color]}) #{start}% #{cursor.round(4)}%"
      end
      "conic-gradient(#{stops.join(', ')})"
    end

    # The donut series as the flat array the Stimulus chart controller reads from a data
    # attribute (DESIGN.md §4 "Charts" — the Chart.js doughnut). Each entry carries the
    # slice's numeric amount (the backend's money string as a plain number, no delimiters, so
    # Chart.js can size the arcs), its visible label, and which token paints it (the colour
    # decision already made in `mortgage_donut`, so the JS never re-derives it). The FE does
    # no math (ARCHITECTURE.md §4).
    def mortgage_donut_data(slices)
      slices.map do |slice|
        { amount: slice[:amount], label: slice[:label], color: slice[:color] }
      end
    end

    # The balance-over-time curve as SVG polyline/area points in a unit viewBox
    # (0..100 × 0..100), derived from the backend's `balance_curve` samples (month →
    # remaining balance). The FE does no math beyond mapping the supplied points into the
    # plot box: x by month over the term, y by balance over the starting loan amount
    # (inverted so a falling balance descends). Returns "x,y x,y …" for the points attr.
    def mortgage_curve_points(curve)
      max_month   = curve.last[:month].to_f
      max_balance = curve.first[:balance].to_f # month 0 = starting loan amount, the peak
      max_month = 1.0 if max_month.zero?        # single-point guard (never in practice)
      max_balance = 1.0 if max_balance.zero?
      curve.map do |point|
        x = point[:month].to_f / max_month * 100
        y = 100 - (point[:balance].to_f / max_balance * 100)
        "#{x.round(3)},#{y.round(3)}"
      end.join(" ")
    end
  end
end
