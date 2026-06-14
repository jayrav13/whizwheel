module Calculators
  module Type
    # Shared behaviour for the guarded numeric attribute types (#109, #110).
    #
    # Two jobs, both grounded in BigDecimal parsing so the guard's accepted set
    # equals what casting accepts losslessly:
    #
    #   - **#cast** routes string input through BigDecimal before the stock cast, so
    #     every numeric form casts losslessly — "2.5e2" → 250, "2e3" → 2000 (the
    #     stock integer cast would give 2, since String#to_i stops at the "e"),
    #     decimals exact (§10). Non-numeric / non-finite strings fall through to the
    #     stock cast (which yields 0/nil) — they are caught by the pre-compute guard
    #     before #compute ever runs, so the lossy fallback value is never used.
    #   - **#valid_raw?** answers the guard: is this RAW (pre-cast) value a valid
    #     number? A value already Numeric/BigDecimal is valid by construction; a
    #     String is valid iff BigDecimal parses it to a finite value (integers add a
    #     whole-number requirement — see Calculators::Type::Integer).
    #
    # Including this module also marks a type as guarded, which is how
    # Calculators::Base.numeric_attribute_names discovers which attributes to inspect.
    module NumericGuard
      def cast(value)
        return super unless value.is_a?(::String)

        parsed = parse_decimal(value)
        parsed.nil? ? super : super(parsed)
      end

      # True when +raw+ is a valid finite number. Subclasses may narrow this
      # (the integer type additionally requires a whole number).
      def valid_raw?(raw)
        numeric_raw?(raw)
      end

      # True when +raw+ parses to a finite number at all (ignoring whole-ness). Used
      # by the guard to distinguish "is not a number" from "must be a whole number".
      def numeric_raw?(raw)
        !to_decimal(raw).nil?
      end

      private

      # The finite BigDecimal value of +raw+, or nil when it is not a finite number.
      # A Numeric raw is valid by construction; a String is parsed by BigDecimal; any
      # other type (an unexpected non-numeric object) is not a number.
      def to_decimal(raw)
        case raw
        when ::Numeric then raw.to_d
        when ::String then parse_decimal(raw)
        end
      end

      # Parse a string to a finite BigDecimal, or nil for garbage / non-finite
      # ("abc", "5 0", "Infinity", "NaN", ""). Callers pass only strings.
      def parse_decimal(string)
        bd = BigDecimal(string, exception: false)
        bd if bd&.finite?
      end
    end
  end
end
