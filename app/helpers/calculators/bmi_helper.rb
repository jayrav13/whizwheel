# Per-calculator helper for BMI (issue #53; split per issue #107). Holds the field-label
# map (single source of truth, DESIGN.md §4), the WHO classification scale metadata, and
# the BMI display formatter. Auto-included into views; slug `bmi` →
# Calculators::BmiHelper::FIELD_LABELS in field_labels_for.
module Calculators
  module BmiHelper
    # The visible label for each BMI input.
    FIELD_LABELS = {
      "unit_system" => "Unit system",
      "weight"      => "Weight",
      "height"      => "Height"
    }.freeze

    # The WHO adult classification scale (issue #53): the band segments the page draws as a
    # thin stacked bar (the WHO scale + marker, DESIGN.md §4) AND lists as a responsive
    # auto-fit stat grid (DESIGN.md §4 "Stat grid"). The backend owns the math
    # (Calculators::Bmi::BANDS); this is display-only metadata — a visible BMI range, a human
    # label, and the band's [lower, upper) bounds within the plotted 15–40 window so the
    # segments size proportionally without a runaway open-ended slice.
    #
    # The finer WHO bands (Severe/Moderate/Mild Thinness, Obese Class I–III) collapse into
    # these four broad bins for the bar; the precise band text comes from `category`.
    SCALE_MIN = 15.0
    SCALE_MAX = 40.0
    BANDS = [
      { label: "Underweight", range: "< 18.5", lower: 15.0, upper: 18.5 },
      { label: "Normal",      range: "18.5–25", lower: 18.5, upper: 25.0 },
      { label: "Overweight",  range: "25–30",   lower: 25.0, upper: 30.0 },
      { label: "Obese",       range: "≥ 30",    lower: 30.0, upper: 40.0 }
    ].freeze

    # The four broad scale bands, each with its percentage width of the 15–40 window and
    # whether the given BMI falls in it (so the view highlights the active segment). A nil
    # BMI (pristine state never renders the scale, but keep it total) marks none active.
    def bmi_scale_bands(bmi)
      span = SCALE_MAX - SCALE_MIN
      value = bmi&.to_f
      BANDS.map do |band|
        width = (band[:upper] - band[:lower]) / span * 100
        active = !value.nil? && value >= band[:lower] && value < band[:upper]
        band.merge(width: width, active: active)
      end
    end

    # Where the marker sits along the 15–40 bar, as a left-offset percentage clamped to the
    # window so an off-the-chart BMI still lands on the bar (a BMI of 12 pins to 0%, 45 to 100%).
    def bmi_marker_position(bmi)
      clamped = bmi.to_f.clamp(SCALE_MIN, SCALE_MAX)
      (clamped - SCALE_MIN) / (SCALE_MAX - SCALE_MIN) * 100
    end

    # BMI for display (ARCHITECTURE.md §10 — the calculator already rounds `bmi` to 1dp;
    # render it with a fixed single decimal so 23 reads "23.0", keeping the figure aligned).
    def bmi_display(value)
      format("%.1f", value)
    end
  end
end
