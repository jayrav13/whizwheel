# Per-calculator helper for Ohm's Law (issue #55; split per issue #107). Holds the
# field-label map (single source of truth, DESIGN.md §4) and the V/I/R/P quantity table
# the result render reads. Auto-included into views; slug `ohms_law` →
# Calculators::OhmsLawHelper::FIELD_LABELS in field_labels_for.
module Calculators
  module OhmsLawHelper
    # The visible label for each Ohm's Law input.
    FIELD_LABELS = {
      "voltage"    => "Voltage (V)",
      "current"    => "Current (I)",
      "resistance" => "Resistance (R)",
      "power"      => "Power (P)"
    }.freeze

    # The four Ohm's Law quantities in V/I/R/P order, each with its label, SI unit, and
    # which result key it reads — drives the result render (§4). The order is fixed so the
    # solved-quantity grid always reads V, I, R, P regardless of which pair was supplied.
    QUANTITIES = [
      { key: :voltage,    label: "Voltage",    unit: "V", symbol: "V" },
      { key: :current,    label: "Current",    unit: "A", symbol: "I" },
      { key: :resistance, label: "Resistance", unit: "Ω", symbol: "R" },
      { key: :power,      label: "Power",      unit: "W", symbol: "P" }
    ].freeze

    # The four Ohm's Law quantities, V/I/R/P order, for the result render — a helper so
    # the view reaches the constant without qualifying it (templates see the module's
    # methods, not its constants).
    def ohms_law_quantities = QUANTITIES

    # The given pair (a Set of result keys) for an Ohm's Law calc — the two quantities
    # the user supplied for the selected mode. Those echo back; the other two are solved
    # and get highlighted in the render (spec issue #55: "highlight the two it solved").
    def ohms_law_given_keys(calc)
      Calculators::OhmsLaw::REQUIRED_INPUTS.fetch(calc.mode, []).to_set
    end
  end
end
