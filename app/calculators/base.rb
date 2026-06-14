module Calculators
  # The contract every calculator inherits (ARCHITECTURE.md §2).
  #
  # A calculator is a pure ActiveModel object: typed attributes + validations,
  # a memoized #result, a #slug, and the unsaved-Calculation builder. No database,
  # no request, no user — that purity is what makes the 100% coverage gate
  # achievable (CLAUDE.md rule #5).
  #
  # Subclasses MUST implement a private #compute that returns a Hash; its keys are
  # the calculator's output contract, surfaced verbatim in the JSON envelope (§4).
  #
  # ## Numeric coercion guard (issues #109, #110)
  #
  # ActiveModel casts an attribute to its declared type BEFORE validations run, and
  # the numeric casts silently swallow bad input:
  #   - `:decimal` turns "abc" into BigDecimal(0) (NOT nil) — so a plain
  #     numericality check passes and the calculator computes on garbage (#110).
  #   - `:integer` truncates "2.5" to 2 — so an `only_integer` numericality check is
  #     unreachable and fractional input is silently accepted (#109).
  #
  # Base fixes this once for every calculator: it captures the RAW (pre-cast) value
  # of each `:decimal`/`:integer` attribute and, in a validation that runs before
  # #compute, rejects a non-blank raw value that is not a valid number (decimal) or
  # not a whole number (integer) — a label-led "is not a number" / "must be an
  # integer" error → 422 via the §4 envelope, never a silent coercion. A blank or
  # omitted raw value is left alone, so each calculator's own presence rules still
  # own "missing input".
  class Base
    include ActiveModel::Model
    include ActiveModel::Attributes

    # A signed decimal: optional sign, digits with an optional fractional part, or a
    # bare/trailing fractional like ".5" / "2." / "-.5", with optional surrounding
    # whitespace. (BigDecimal accepts all of these; this is the pre-cast gate.)
    NUMERIC = /\A\s*[-+]?(\d+\.?\d*|\.\d+)\s*\z/

    validate :numeric_attributes_parse

    def initialize(...)
      @raw_numeric_inputs = {}
      super
    end

    # Calculators::Percentage => "percentage"
    def self.slug = name.demodulize.underscore

    # "percentage" => Calculators::Percentage (or nil if no such calculator).
    # The controller's only lookup path — keeps routing registration-free (§3).
    def self.lookup(slug) = "Calculators::#{slug.to_s.camelize}".safe_constantize

    # The names (as strings) of attributes declared with a numeric cast
    # (:decimal / :integer) — the ones whose raw input the coercion guard inspects.
    # Memoized per class.
    def self.numeric_attribute_names
      @numeric_attribute_names ||= attribute_types.filter_map do |name, type|
        name if %i[decimal integer].include?(type.type)
      end
    end

    # Capture the raw, pre-cast value of every numeric attribute as it is assigned,
    # BEFORE ActiveModel casts it (and loses "abc" → 0 / "2.5" → 2). The captured
    # values are what #numeric_attributes_parse validates. This intercepts the
    # assignment path every calculator uses (.new / assign_attributes / update).
    def assign_attributes(attributes)
      attributes.to_h.each do |name, value|
        key = name.to_s
        @raw_numeric_inputs[key] = value if self.class.numeric_attribute_names.include?(key)
      end
      super
    end

    # The computed result Hash, or nil when the inputs are invalid. Memoized.
    def result
      @result ||= (compute if valid?)
    end

    # An UNSAVED Calculation. Touches no database; assigns no user — the
    # controller does that (ARCHITECTURE.md §1, §5).
    def to_calculation
      Calculation.new(calculator: self.class.slug, inputs: attributes, result: result)
    end

    private

    # The coercion guard (#109, #110). For each numeric attribute given a non-blank
    # raw value, require that the raw value parses cleanly — as a number for
    # `:decimal`, as a WHOLE number for `:integer`. A blank/omitted raw value is
    # skipped so each calculator's presence rules still report missing input.
    def numeric_attributes_parse
      @raw_numeric_inputs.each do |name, raw|
        next if blank_raw?(raw)

        string = raw.to_s
        if !NUMERIC.match?(string)
          errors.add(name, :not_a_number)
        elsif integer_attribute?(name) && fractional?(string)
          errors.add(name, :not_an_integer, message: "must be a whole number")
        end
      end
    end

    # A raw value counts as "not supplied" when it is nil or an all-whitespace
    # string — exactly the cases a calculator's presence validation owns.
    def blank_raw?(raw)
      raw.nil? || (raw.is_a?(String) && raw.strip.empty?)
    end

    def integer_attribute?(name)
      self.class.attribute_types[name].type == :integer
    end

    # True when a numeric string carries a non-zero fractional part (e.g. "2.5"),
    # i.e. it is not a whole number. "2" / "2.0" / "2." are whole and allowed.
    def fractional?(string)
      !BigDecimal(string.strip).frac.zero?
    end

    def compute = raise(NotImplementedError)
  end
end
