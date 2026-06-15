# Per-calculator helper for Compound Interest (issue #189; spec issue #188). Holds the
# field-label map (single source of truth, DESIGN.md §4) plus the chart-derivation helpers
# (the growth-series curve points + endpoint labels, and the principal-vs-interest donut
# series). The FE does NO math beyond mapping the backend's already-computed figures into
# display proportions (ARCHITECTURE.md §4 — the backend owns every number; growth_series
# exists precisely so the curve is drawn without doing math). Auto-included into views;
# slug `compound_interest` → Calculators::CompoundInterestHelper::FIELD_LABELS.
module Calculators
  module CompoundInterestHelper
    # The visible label for each Compound Interest input — drives error phrasing
    # (CalculatorsHelper#calculator_error_messages) against the field labels the page shows.
    FIELD_LABELS = {
      "principal"   => "Principal",
      "annual_rate" => "Annual interest rate",
      "years"       => "Time",
      "compounding" => "Compounding frequency"
    }.freeze

    # The compounding modes for the picker (DESIGN.md §4 "Mode picker"): the option value,
    # its visible label, and a one-line helper naming how many times a year interest is
    # added (m). Five modes, several multi-word → the `.mode-option` selectable option list
    # (N ≥ 4 / multi-word labels), not a segmented control. The order matches the spec's
    # annually→daily table. The frequency counts are descriptive copy (the periods/year the
    # spec assigns each mode), not a computed figure.
    COMPOUNDING_MODES = [
      [ "annually",     "Annually",      "Once a year" ],
      [ "semiannually", "Semiannually",  "Twice a year" ],
      [ "quarterly",    "Quarterly",     "4 times a year" ],
      [ "monthly",      "Monthly",       "12 times a year" ],
      [ "daily",        "Daily",         "365 times a year" ]
    ].freeze

    # The compounding modes for the picker rows (the page iterates these to render the
    # .mode-option list). A thin accessor so the view reads the constant through the helper
    # rather than reaching for the fully-qualified constant in markup.
    def compound_interest_modes = COMPOUNDING_MODES

    # The growth curve as the flat array the Stimulus chart controller reads from a data
    # attribute (DESIGN.md §4 "Charts" — the lightweight-charts area/line). Each point is
    # the backend's end-of-year `{ year, balance }` sample mapped to `{ year, balance }`
    # number-friendly strings the chart can plot. The backend already emits the series in
    # order; this only forwards it (no math — ARCHITECTURE.md §4).
    def compound_interest_curve_data(series)
      series.map { |point| { year: point[:year].to_s, balance: point[:balance] } }
    end

    # The growth curve as SVG polyline/area points in a unit viewBox (0..100 × 0..100) for
    # the always-present no-JS fallback (DESIGN.md §4/§6). Maps the backend's `{ year,
    # balance }` samples into the plot box: x by year over the term, y by balance over the
    # final (largest) balance, inverted so a rising balance climbs. The FE does no math
    # beyond this display projection — the balances themselves are the backend's.
    def compound_interest_curve_points(series)
      max_year    = series.last[:year].to_f
      max_balance = series.last[:balance].to_f # the final year = the peak balance
      max_year = 1.0 if max_year.zero?         # single-point guard (years validates > 0)
      max_balance = 1.0 if max_balance.zero?
      series.map do |point|
        x = point[:year].to_f / max_year * 100
        y = 100 - (point[:balance].to_f / max_balance * 100)
        "#{x.round(3)},#{y.round(3)}"
      end.join(" ")
    end

    # The principal-vs-interest donut series (DESIGN.md §4 "Charts"): two slices comparing
    # the entered principal against the total interest earned. Each slice carries its share
    # (0–100, for the conic stops) and which token paints it — the LARGER slice gets accent
    # green per DESIGN.md §1, the smaller coral. The backend owns the figures (money
    # strings); this only derives display proportions. Total is always > 0 (principal
    # validates greater_than 0).
    def compound_interest_donut(principal, total_interest)
      p = BigDecimal(principal)
      i = BigDecimal(total_interest)
      total = p + i
      p_pct = (p / total * 100).to_f
      i_pct = 100.0 - p_pct
      principal_bigger = p >= i
      [
        { key: :principal,      label: "Principal",      amount: principal,      pct: p_pct, color: principal_bigger ? "accent" : "primary" },
        { key: :total_interest, label: "Total interest", amount: total_interest, pct: i_pct, color: principal_bigger ? "primary" : "accent" }
      ]
    end

    # The conic-gradient value for the no-JS fallback donut: the first slice fills 0→pct,
    # the second the remainder. Composed from the two token colours so the chart needs no
    # inline hex (DESIGN.md §5 guardrail — colours come from the @theme CSS custom props).
    def compound_interest_donut_gradient(slices)
      first = slices.first
      stop = first[:pct].round(4)
      "conic-gradient(var(--color-#{first[:color]}) 0 #{stop}%, var(--color-#{slices.last[:color]}) #{stop}% 100%)"
    end

    # The donut series as the flat object the Stimulus chart controller reads from a data
    # attribute (the Chart.js doughnut). It carries each slice's numeric amount, its visible
    # label, and which token paints it (the colour decision — larger slice green, smaller
    # coral — already made in #compound_interest_donut, so the JS never re-derives it).
    # Amounts are the backend's money strings as plain numbers (no delimiters) so Chart.js
    # can size the arcs; the FE does no math (ARCHITECTURE.md §4).
    def compound_interest_donut_data(slices)
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

    # The visible label for a compounding mode value (e.g. "monthly" → "Monthly"), used in
    # the result sentence. Falls back to a humanized value for an unmapped mode (never in
    # practice — the value is validated into COMPOUNDING_MODES' keys before the result
    # renders).
    def compounding_label(value)
      row = COMPOUNDING_MODES.find { |mode_value, _, _| mode_value == value }
      row ? row[1] : value.to_s.humanize
    end
  end
end
