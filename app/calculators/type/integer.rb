module Calculators
  module Type
    # An `:integer` attribute that casts losslessly through BigDecimal — so whole
    # values written in scientific notation survive ("2e3" → 2000, where the stock
    # integer cast yields 2) — and validates raw input as a finite WHOLE number.
    # Installed automatically when a calculator declares an attribute `:integer`
    # (Calculators::Base::NUMERIC_TYPES); calculators never name it directly.
    #
    # A fractional raw value ("2.5", or a non-whole Numeric like BigDecimal("2.5"))
    # is rejected by the guard rather than silently truncated (#109).
    class Integer < ActiveModel::Type::Integer
      include NumericGuard

      # Valid only when the raw value is a finite number AND a whole one.
      def valid_raw?(raw)
        decimal = to_decimal(raw)
        !decimal.nil? && decimal.frac.zero?
      end
    end
  end
end
