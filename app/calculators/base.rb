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
  # the stock numeric casts silently swallow bad input:
  #   - `:decimal` turns "abc" into BigDecimal(0) (NOT nil) — so a plain
  #     numericality check passes and the calculator computes on garbage (#110).
  #   - `:integer` truncates "2.5" to 2, and parses "2e3" as 2 (String#to_i stops
  #     at the "e") — so fractional/scientific input is silently mangled (#109).
  #
  # Base fixes this once for every calculator, in two cooperating pieces:
  #
  #   1. **Correct casting** — declaring an attribute `:decimal`/`:integer`
  #      transparently installs a `Calculators::Type` subclass (see ::attribute)
  #      that routes string casting through BigDecimal, so every numeric form the
  #      guard accepts casts *losslessly*: "2.5e2" → 250, "2e3" → 2000 (not 2),
  #      decimals stay exact (§10).
  #   2. **A pre-compute guard** — Base captures the RAW (pre-cast) value of each
  #      numeric attribute at the cast seam (#_write_attribute, the one method every
  #      assignment path funnels through — .new, assign_attributes, update, AND the
  #      per-attribute writer `calc.foo = …`) and, in a validation that runs before
  #      #compute, rejects any non-blank raw value the type deems invalid: a label-
  #      led "is not a number" / "must be a whole number" error → 422 via the §4
  #      envelope, never a silent coercion.
  #
  # Validity is decided by *parsing*, not a regex: the accepted set equals what the
  # corrected cast accepts losslessly — every BigDecimal-parseable finite number,
  # including scientific notation ("1e6", "2.5e2", "1E3"), signed and bare-
  # fractional forms ("-.5", "2."), with integers additionally required to be whole.
  # Genuine garbage ("abc", "5 0", "3a", "Infinity", "NaN") is rejected; a raw value
  # that is already Numeric/BigDecimal is valid by construction. A blank or omitted
  # raw value is left alone, so each calculator's own presence rules still own
  # "missing input".
  #
  # ## Blank input on a defaulted numeric attribute (issue #213)
  #
  # ActiveModel applies an attribute's `default:` only when the key is ABSENT. An HTML
  # form (or any API client) that submits the key with an empty string casts it to nil
  # — NOT to the default — so a `default: 0` optional field defeats its own default and
  # `#compute` receives nil (e.g. `nil * 12` → NoMethodError → 500). Base closes this
  # once for every calculator: for any numeric attribute declared WITH a `default:`, a
  # blank raw value (nil or whitespace-only string) is coerced to the declared default
  # at the cast seam (#_write_attribute) — before validation and before #compute — so a
  # blank optional numeric field behaves identically to an omitted one (the declared
  # default), and #compute never sees nil for a defaulted numeric. A numeric attribute
  # WITHOUT a default is untouched: its blank stays nil, for the calculator's own
  # presence rules to report.
  class Base
    include ActiveModel::Model
    include ActiveModel::Attributes

    # The `:decimal`/`:integer` symbols a calculator declares are mapped to these
    # BigDecimal-backed subclasses (see ::attribute), which both cast losslessly and
    # expose #valid_raw? for the coercion guard.
    NUMERIC_TYPES = { decimal: Calculators::Type::Decimal, integer: Calculators::Type::Integer }.freeze

    validate :numeric_attributes_parse

    def initialize(...)
      @raw_numeric_inputs = {}
      super
    end

    # Install the guarded numeric type whenever a calculator declares `:decimal` or
    # `:integer` — so calculators keep writing the plain symbols and automatically
    # get lossless casting + the coercion guard, with no per-calculator change. Any
    # macro options (e.g. `default:`) pass straight through to ActiveModel; our
    # numeric types take no type-specific options today, so the type is built bare.
    #
    # When a numeric attribute is declared WITH a `default:`, record that default so
    # blank input on it is coerced to the default rather than reaching #compute as nil
    # (#213). The map is per-class and inherited-class-safe: a subclass starts from its
    # parent's defaults so a calculator inherits any base-declared defaulted numerics.
    def self.attribute(name, type = nil, **options)
      if NUMERIC_TYPES.key?(type)
        numeric_defaults[name.to_s] = options[:default] if options.key?(:default)
        type = NUMERIC_TYPES.fetch(type).new
      end
      super(name, type, **options)
    end

    # Per-class map of `attribute name (String) => declared default` for numeric
    # attributes given a `default:`. Seeded from the superclass so a subclass inherits
    # its parent's defaulted numerics, then owns its own copy (no cross-class leakage).
    def self.numeric_defaults
      @numeric_defaults ||= superclass.respond_to?(:numeric_defaults) ? superclass.numeric_defaults.dup : {}
    end

    # Declare an attribute as a variable-length LIST input — one posted as
    # `inputs[name][]` (e.g. Average Return's `returns`). This does NOT change how the
    # value is stored (the attribute itself is declared separately, untyped, so the
    # submitted Array passes through and the calculator owns the parse — like the
    # string-list calculators own their split). It only records the name so the
    # controller permits that key as an ARRAY in strong params (CalculatorsController
    # #calculator_params) rather than a scalar — registration-free, the calculator's
    # own declaration drives it. Inherited-class-safe: a subclass starts from its
    # parent's set, then owns its own copy.
    def self.array_attribute(name)
      array_attribute_names << name.to_s
    end

    # The names (as strings) of attributes declared via ::array_attribute — the LIST
    # inputs the controller permits as arrays. Seeded from the superclass so a subclass
    # inherits its parent's array attributes, then owns its own copy (no cross-class
    # leakage). Empty for the common scalar-only calculator.
    def self.array_attribute_names
      @array_attribute_names ||=
        superclass.respond_to?(:array_attribute_names) ? superclass.array_attribute_names.dup : []
    end

    # Calculators::Percentage => "percentage"
    def self.slug = name.demodulize.underscore

    # "percentage" => Calculators::Percentage (or nil if no such calculator).
    # The controller's only lookup path — keeps routing registration-free (§3).
    def self.lookup(slug) = "Calculators::#{slug.to_s.camelize}".safe_constantize

    # The names (as strings) of attributes whose declared type is one of our guarded
    # numeric types — the ones whose raw input the coercion guard inspects. Memoized
    # per class.
    def self.numeric_attribute_names
      @numeric_attribute_names ||= attribute_types.filter_map do |name, type|
        name if type.is_a?(Calculators::Type::NumericGuard)
      end
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

    # The single seam every assignment path funnels through — .new, assign_attributes,
    # update, AND the per-attribute writer (`calc.foo = …`). Capturing the RAW value
    # here (before ActiveModel casts it and loses "abc" → 0 / "2.5" → 2) makes the
    # guard assignment-path-independent: it fires however the attribute was set, and a
    # corrective re-assignment overwrites the captured raw (no stale false 422).
    #
    # For a numeric attribute declared WITH a `default:` (#213), a blank value (nil or
    # whitespace-only string) is replaced by the declared default before both the raw
    # capture and the cast — so a blank optional field behaves like an omitted one and
    # #compute never sees nil for a defaulted numeric. The substituted value is a valid
    # number, so the captured raw passes the coercion guard.
    def _write_attribute(name, value)
      key = name.to_s
      value = self.class.numeric_defaults[key] if numeric_default?(key) && blank_raw?(value)
      @raw_numeric_inputs[key] = value if self.class.numeric_attribute_names.include?(key)
      super(name, value)
    end

    # True when +key+ names a numeric attribute that was declared with a `default:`.
    def numeric_default?(key) = self.class.numeric_defaults.key?(key)

    # The coercion guard (#109, #110). For each numeric attribute given a non-blank
    # raw value, ask its type whether the raw value is valid — a finite number for
    # `:decimal`, a finite WHOLE number for `:integer`. A blank/omitted raw value is
    # skipped so each calculator's presence rules still report missing input. When an
    # integer's raw value parses as a number but is not whole (e.g. "2.5"), the error
    # is the more specific "must be a whole number"; otherwise it is "is not a number".
    def numeric_attributes_parse
      @raw_numeric_inputs.each do |name, raw|
        next if blank_raw?(raw)

        type = self.class.attribute_types[name]
        next if type.valid_raw?(raw)

        if type.numeric_raw?(raw)
          errors.add(name, :not_an_integer, message: "must be a whole number")
        else
          errors.add(name, :not_a_number)
        end
      end
    end

    # A raw value counts as "not supplied" when it is nil or an all-whitespace
    # string — exactly the cases a calculator's presence validation owns.
    def blank_raw?(raw)
      raw.nil? || (raw.is_a?(String) && raw.strip.empty?)
    end

    def compute = raise(NotImplementedError)
  end
end
