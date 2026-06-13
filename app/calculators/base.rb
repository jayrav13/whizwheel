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
  class Base
    include ActiveModel::Model
    include ActiveModel::Attributes

    # Calculators::Percentage => "percentage"
    def self.slug = name.demodulize.underscore

    # "percentage" => Calculators::Percentage (or nil if no such calculator).
    # The controller's only lookup path — keeps routing registration-free (§3).
    def self.lookup(slug) = "Calculators::#{slug.to_s.camelize}".safe_constantize

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

    def compute = raise(NotImplementedError)
  end
end
