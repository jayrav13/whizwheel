# Per-calculator helper for House Affordability (issue #259; per-calculator split per
# issue #107). Holds the field-label map (the single source of truth for the form labels
# AND the error-phrasing map, DESIGN.md §4) and the monthly-housing-budget donut helpers
# (the breakdown of the binding DTI housing cap into its four components — principal &
# interest, property tax, home insurance, HOA — the conic-gradient no-JS fallback, and the
# flat payload the Stimulus chart controller reads).
#
# The FE does NO math (ARCHITECTURE.md §4 — all math stays server-side). The backend's
# envelope gives `max_pi` and `max_monthly_housing`; the four budget components are the
# already-computed `max_pi` plus the fixed monthly cost inputs the user entered
# (property tax / insurance / HOA), which the calc instance still carries — so the donut
# only maps figures the backend already holds into display proportions, deriving nothing.
# Auto-included into views; slug `house_affordability` →
# Calculators::HouseAffordabilityHelper::FIELD_LABELS.
module Calculators
  module HouseAffordabilityHelper
    # The visible label for each House Affordability input — the single source of truth for
    # the form labels AND the error-phrasing map (DESIGN.md §4: phrase errors against the
    # visible label, never the raw attribute key).
    FIELD_LABELS = {
      "annual_income"          => "Annual income",
      "monthly_debts"          => "Monthly debts",
      "down_payment"           => "Down payment",
      "annual_rate"            => "Annual interest rate",
      "loan_term_years"        => "Loan term",
      "front_dti"              => "Front-end DTI",
      "back_dti"               => "Back-end DTI",
      "monthly_property_tax"   => "Monthly property tax",
      "monthly_home_insurance" => "Monthly home insurance",
      "monthly_hoa"            => "Monthly HOA fee"
    }.freeze

    # The donut palette, in slice order (DESIGN.md §1: largest slice green → coral → amber →
    # a fourth quiet token for the smallest component). The housing-budget donut splits the
    # binding DTI housing cap into its four monthly components, largest-first: P&I always
    # leads (it's what's left after the fixed costs), so we paint accent green, then coral,
    # amber, and a quiet label tone.
    DONUT_COLORS = %w[accent primary amber faint].freeze

    # The four monthly-housing-budget components, ordered P&I-first then the fixed ownership
    # costs, as {label, amount} pairs — the raw figures the backend already holds (`max_pi`
    # from the envelope; tax / insurance / HOA the entered inputs). All sum to
    # `max_monthly_housing`. Money strings (2dp) so the donut helpers and the legend share
    # one source.
    def house_affordability_budget_components(calc)
      [
        { label: "Principal & interest", amount: calc.result[:max_pi] },
        { label: "Property tax",         amount: money_2dp(calc.monthly_property_tax) },
        { label: "Home insurance",       amount: money_2dp(calc.monthly_home_insurance) },
        { label: "HOA",                  amount: money_2dp(calc.monthly_hoa) }
      ]
    end

    # The donut series for the housing-budget breakdown (DESIGN.md §4 "Charts"). Drops any
    # zero-amount component (an omitted tax/insurance/HOA contributes nothing to the housing
    # payment, so it should not draw a slice or clutter the legend), then attaches each
    # remaining slice's share of the total (0–100, for the conic stops) and its token colour
    # by position. `max_pi > 0` is guaranteed (the backend rejects a non-positive P&I), so
    # the total is always positive.
    def house_affordability_donut(calc)
      components = house_affordability_budget_components(calc)
                     .reject { |c| BigDecimal(c[:amount]).zero? }
      total = components.sum { |c| BigDecimal(c[:amount]) }
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
    def house_affordability_donut_gradient(slices)
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
    # slice's numeric amount (the money string as a plain number, so Chart.js can size the
    # arcs), its visible label, and which token paints it (the colour decision already made
    # in `house_affordability_donut`, so the JS never re-derives it).
    def house_affordability_donut_data(slices)
      slices.map do |slice|
        { amount: slice[:amount], label: slice[:label], color: slice[:color] }
      end
    end

    private

    # A two-decimal money string for an input figure the backend holds but doesn't echo in
    # the envelope (tax / insurance / HOA). Mirrors the calculator's own cent formatting so
    # the donut components read consistently with `max_pi`; pure display formatting, no math.
    def money_2dp(value)
      format("%.2f", BigDecimal(value.to_s).round(2, BigDecimal::ROUND_HALF_UP))
    end
  end
end
