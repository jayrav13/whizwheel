module Calculators
  module Type
    # A `:decimal` attribute that casts losslessly (string → exact BigDecimal, via
    # NumericGuard#cast) and validates raw input by parsing (NumericGuard#valid_raw?).
    # Installed automatically when a calculator declares an attribute `:decimal`
    # (Calculators::Base::NUMERIC_TYPES); calculators never name it directly.
    class Decimal < ActiveModel::Type::Decimal
      include NumericGuard
    end
  end
end
