# Per-calculator helper for the Auto Loan calculator (spec issue #251; split per issue
# #107). Holds the field-label map (single source of truth for error phrasing, DESIGN.md
# §4) and the display-derivation helpers the result partial reads — the amount-financed
# breakdown rows, the principal-vs-interest donut series, and the balance-over-time curve
# points. The FE does NO math beyond mapping the backend's already-computed figures into
# display proportions (ARCHITECTURE.md §4): the backend emits the amount financed, the
# sales tax, the totals and the full schedule; this only formats and arranges them.
# Auto-included into views; slug `auto_loan` → Calculators::AutoLoanHelper::FIELD_LABELS.
module Calculators
  module AutoLoanHelper
    # The visible label for each Auto Loan input — what the error phrasing reads back
    # (DESIGN.md §4: "phrase each message against the field's visible label"). These mirror
    # the labels the page renders on each field.
    FIELD_LABELS = {
      "auto_price"     => "Vehicle price",
      "term_months"    => "Loan term",
      "annual_rate"    => "Annual interest rate",
      "down_payment"   => "Down payment",
      "trade_in"       => "Trade-in value",
      "sales_tax_rate" => "Sales tax",
      "fees"           => "Title, registration & other fees"
    }.freeze

    # The amount-financed breakdown — the auto-specific story the calculator.net auto-loan
    # page tells: how the vehicle price, sales tax and fees roll up and the trade-in + down
    # payment net out to the amount actually financed. Each row is { label, amount (money
    # string from the echoed inputs / computed result), sign (:add | :subtract) } so the
    # partial can render a +/− itemized list ending in the financed total. The backend owns
    # the computed sales_tax and amount_financed; the input figures (price, down, trade-in,
    # fees) are the echoed request values. Returns only the rows that carry a non-zero
    # figure beyond the always-shown price, so a bare-bones loan (no tax/fees/trade-in)
    # doesn't list a row of zeros.
    def auto_loan_breakdown(calc)
      r = calc.result
      inputs = calc.attributes
      rows = [ { label: "Vehicle price", amount: money_str(inputs["auto_price"]), sign: :add } ]
      rows << { label: "Sales tax", amount: r[:sales_tax], sign: :add } unless zero_money?(r[:sales_tax])
      rows << { label: "Fees", amount: money_str(inputs["fees"]), sign: :add } unless zero_money?(inputs["fees"])
      rows << { label: "Down payment", amount: money_str(inputs["down_payment"]), sign: :subtract } unless zero_money?(inputs["down_payment"])
      rows << { label: "Trade-in value", amount: money_str(inputs["trade_in"]), sign: :subtract } unless zero_money?(inputs["trade_in"])
      rows
    end

    # The donut series for the Auto Loan result (DESIGN.md §4 "Charts"). The donut compares
    # the amount financed (principal) vs. the total interest. Returns each slice with its
    # share (0–100, for the conic stops) and which token paints it — the LARGER slice gets
    # accent green per DESIGN.md §1, the smaller gets coral. The backend owns the figures;
    # this only derives display proportions. (Mirrors AmortizationHelper#amortization_donut.)
    def auto_loan_donut(result)
      financed = BigDecimal(result[:amount_financed])
      interest = BigDecimal(result[:total_interest])
      total    = financed + interest
      # total is always > 0 here (amount_financed validates > 0).
      f_pct = (financed / total * 100).to_f
      i_pct = 100.0 - f_pct
      financed_bigger = financed >= interest
      [
        { key: :principal, label: "Amount financed", amount: result[:amount_financed], pct: f_pct, color: financed_bigger ? "accent" : "primary" },
        { key: :interest,  label: "Total interest",  amount: result[:total_interest],  pct: i_pct, color: financed_bigger ? "primary" : "accent" }
      ]
    end

    # The conic-gradient value for the no-JS fallback donut: the first slice fills 0→pct,
    # the second fills the remainder. Composed of the two TOKEN colours (CSS custom
    # properties) so the chart needs no inline hex (DESIGN.md §5 guardrail).
    def auto_loan_donut_gradient(slices)
      first = slices.first
      stop = first[:pct].round(4)
      "conic-gradient(var(--color-#{first[:color]}) 0 #{stop}%, var(--color-#{slices.last[:color]}) #{stop}% 100%)"
    end

    # The donut series as the flat object the Stimulus chart controller reads from a data
    # attribute (DESIGN.md §4 "Charts" — the Chart.js doughnut). It carries each slice's
    # numeric amount (a plain money string Chart.js parses), visible label, and which token
    # paints it (the colour decision already made in auto_loan_donut, so the JS never
    # re-derives it). The FE does no math (ARCHITECTURE.md §4).
    def auto_loan_donut_data(slices)
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

    # The balance-over-time curve, derived from the schedule the backend emits (the auto
    # loan envelope has no separate chart payload — the schedule's running `balance` IS the
    # curve). Returns [{ month, balance }, …] starting at month 0 = the amount financed (the
    # peak), then each scheduled month's remaining balance, in order — exactly the shape the
    # lightweight-charts controller reads. The FE does no math: it reads the backend's
    # balances and prepends the starting financed amount as month 0.
    def auto_loan_balance_curve(result)
      start = { month: 0, balance: result[:amount_financed] }
      points = result[:schedule].map { |row| { month: row[:month], balance: row[:balance] } }
      [ start ] + points
    end

    # The balance curve as SVG polyline points in a 0..100 × 0..100 unit viewBox (the no-JS
    # fallback line), derived from the curve above: x by month over the term, y by balance
    # over the starting financed amount (inverted so a falling balance descends). Returns
    # "x,y x,y …". (Mirrors AmortizationHelper#amortization_curve_points.)
    def auto_loan_curve_points(curve)
      max_month   = curve.last[:month].to_f
      max_balance = curve.first[:balance].to_f # month 0 = amount financed, the peak
      max_month = 1.0 if max_month.zero?        # single-point guard (never in practice)
      max_balance = 1.0 if max_balance.zero?
      curve.map do |point|
        x = point[:month].to_f / max_month * 100
        y = 100 - (point[:balance].to_f / max_balance * 100)
        "#{x.round(3)},#{y.round(3)}"
      end.join(" ")
    end

    private

    # An echoed input value coerced to a 2dp money string, so the breakdown can format an
    # input the same way money_display handles the computed money strings. The optional
    # inputs all carry a `default: 0` on the calculator, so a blank or omitted field arrives
    # here already as BigDecimal(0) — never nil — and this just rounds + stringifies it.
    def money_str(value)
      BigDecimal(value.to_s).round(2, BigDecimal::ROUND_HALF_UP).to_s("F")
    end

    # Whether a money figure (a string like "0.00"/"0", or a numeric/BigDecimal/nil input)
    # is zero — used to drop empty breakdown rows. Normalizes through money_str first.
    def zero_money?(value)
      str = value.is_a?(String) ? value : money_str(value)
      BigDecimal(str).zero?
    end
  end
end
