module Calculators
  # calculator.net's BMI page, as a multi-mode (two unit systems) calculator
  # (spec issue #52). Computes Body Mass Index from a person's weight and height
  # and classifies it into the WHO adult band.
  #
  # `unit_system` selects the formula; both modes resolve to the same kg/m² BMI
  # scale, so the classification bands apply uniformly regardless of input units:
  #
  #   us     → BMI = 703 × weight_lb / height_in²   (height is total inches)
  #   metric → BMI = weight_kg / (height_cm / 100)²  (height in metres, squared)
  #
  # `bmi` is computed at full BigDecimal precision and rounded to 1 decimal place
  # for display (half-up); `category` is the WHO adult band, derived from the RAW
  # (unrounded) BMI (§10).
  class Bmi < Base
    UNIT_SYSTEMS = %w[us metric].freeze

    # US imperial constant: BMI = 703 × lb / in².
    US_FACTOR = BigDecimal(703)
    # Centimetres per metre — metric height is collected in cm, the formula needs m.
    CM_PER_M = BigDecimal(100)
    # Display precision for the reported BMI.
    DISPLAY_DP = 1

    # WHO adult classification bands, [lower, upper) — lower inclusive, upper
    # exclusive — matching calculator.net. Ordered low→high by their (exclusive)
    # upper bound; the first band the BMI falls under wins, and the final
    # open-ended band (nil upper) catches everything from 40 up.
    BANDS = [
      [ BigDecimal("16"),   "Severe Thinness" ],
      [ BigDecimal("17"),   "Moderate Thinness" ],
      [ BigDecimal("18.5"), "Mild Thinness" ],
      [ BigDecimal("25"),   "Normal" ],
      [ BigDecimal("30"),   "Overweight" ],
      [ BigDecimal("35"),   "Obese Class I" ],
      [ BigDecimal("40"),   "Obese Class II" ],
      [ nil,                "Obese Class III" ]
    ].freeze

    attribute :unit_system, :string
    attribute :weight, :decimal
    attribute :height, :decimal

    validates :unit_system, presence: true, inclusion: { in: UNIT_SYSTEMS }
    validates :weight, presence: true, numericality: { greater_than: 0 }
    validates :height, presence: true, numericality: { greater_than: 0 }

    private

    def compute
      raw = raw_bmi
      { bmi: raw.round(DISPLAY_DP), category: classify(raw) }
    end

    # The unit-system-specific BMI formula. `unit_system` is validated into
    # UNIT_SYSTEMS before #compute runs (it only runs when valid?), so the two
    # branches are exhaustive — a two-way `if`/`else` keeps both reachable (no
    # unreachable implicit-`else` the way a `case` without `else` would have).
    def raw_bmi
      if unit_system == "us"
        US_FACTOR * weight / (height * height)
      else
        metres = height / CM_PER_M
        weight / (metres * metres)
      end
    end

    # The WHO adult band for a raw BMI: the first band whose (exclusive) upper
    # bound the BMI is below; the open-ended final band catches the rest.
    def classify(bmi)
      _, category = BANDS.find { |upper, _| upper.nil? || bmi < upper }
      category
    end
  end
end
