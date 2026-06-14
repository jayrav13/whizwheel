module Calculators
  # calculator.net's BMI page, as a single multi-mode calculator (spec issue #52).
  # Body Mass Index from weight + height in one of two unit systems, plus the WHO
  # adult classification band as a separate text output.
  #
  # `unit_system` selects the formula family — both modes resolve to the same kg/m²
  # BMI scale, so the classification bands apply uniformly:
  #   us     → BMI = 703 × weight_lb / height_in²
  #   metric → BMI = weight_kg / (height_cm / 100)²   (kg over height-in-meters²)
  #
  # `bmi` is kept at full BigDecimal precision and rounded to 1 dp for display;
  # `category` is the WHO band derived from the RAW (unrounded) BMI (§10).
  class Bmi < Base
    UNIT_SYSTEMS = %w[us metric].freeze

    SEVEN_OH_THREE = BigDecimal(703)
    HUNDRED = BigDecimal(100)

    # WHO adult classification, lower bound inclusive / upper bound exclusive
    # (bands are [lower, upper)). Ordered ascending; the first matching band wins.
    BANDS = [
      [ BigDecimal("16"),   "Severe Thinness" ],
      [ BigDecimal("17"),   "Moderate Thinness" ],
      [ BigDecimal("18.5"), "Mild Thinness" ],
      [ BigDecimal("25"),   "Normal" ],
      [ BigDecimal("30"),   "Overweight" ],
      [ BigDecimal("35"),   "Obese Class I" ],
      [ BigDecimal("40"),   "Obese Class II" ]
    ].freeze
    OBESE_CLASS_III = "Obese Class III" # the open-ended ≥ 40 band

    attribute :unit_system, :string
    attribute :weight, :decimal
    attribute :height, :decimal

    validates :unit_system, presence: true, inclusion: { in: UNIT_SYSTEMS }
    validates :weight, presence: true, numericality: { greater_than: 0 }
    validates :height, presence: true, numericality: { greater_than: 0 }

    private

    def compute
      raw = raw_bmi
      { bmi: raw.round(1), category: classify(raw) }
    end

    # `unit_system` is validated into UNIT_SYSTEMS before #compute runs (it only
    # runs when valid?), so this two-way branch has no unreachable fallback.
    def raw_bmi
      if unit_system == "us"
        SEVEN_OH_THREE * weight / (height * height)
      else
        meters = height / HUNDRED
        weight / (meters * meters)
      end
    end

    def classify(bmi)
      band = BANDS.find { |upper, _label| bmi < upper }
      band ? band.last : OBESE_CLASS_III
    end
  end
end
