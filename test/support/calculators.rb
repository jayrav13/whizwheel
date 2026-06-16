# A test-only calculator for exercising the scaffolding (Calculators::Base and the
# dynamic CalculatorsController) WITHOUT a real calculator. The first real calculator,
# Percentage, is built by the backend agent — that is the experiment's first measurement
# of agent output, so it must not be hand-written here as test plumbing.
#
# It is a genuine `Calculators::` constant (so `Base.lookup("test_double")` resolves it),
# but it lives under test/ and has no file in app/calculators/, so Zeitwerk never manages
# or eager-loads it — it exists only once this file is required by a test.
module Calculators
  class TestDouble < Base
    attribute :x, :decimal
    validates :x, presence: true, numericality: true

    private

    def compute = { doubled: x * 2 }
  end

  # Exercises Base's numeric coercion guard (#109, #110) directly at the contract
  # level: a :decimal, an :integer, and a non-numeric :string attribute so all the
  # guard's branches are reachable without leaning on any one real calculator. No
  # presence rules — the guard alone owns "non-numeric / non-integer raw input".
  class NumericGuardDouble < Base
    attribute :amount, :decimal
    attribute :count, :integer
    attribute :label, :string

    private

    def compute = { amount: amount, count: count, label: label }
  end

  # A page-backed calculator whose stub page (test/support/views/calculators/
  # buggy_page_double.html.erb) renders a partial that does NOT exist — so #show raises
  # ActionView::MissingTemplate from WITHIN a real, built page's render (#partial == true).
  # ActionView wraps that in-template error in ActionView::Template::Error (the
  # MissingTemplate is its #cause), so it bypasses the controller's narrow
  # `rescue ActionView::MissingTemplate` entirely and propagates — the #214 case the rescue
  # must NOT swallow. Proves the rescue is tight: a genuine template bug inside a shipped
  # page still surfaces as a 500, never masked as the coming-soon page.
  class BuggyPageDouble < Base
    attribute :x, :decimal

    private

    def compute = { x: x }
  end

  # Exercises Base's blank-defaults-the-default coercion (#213): an optional :decimal
  # and an optional :integer each with a non-zero `default:`, and a REQUIRED numeric
  # attribute with NO default. #compute does arithmetic that would 500 on a nil (the
  # `nil * 12` shape from the issue), so a blank optional field must arrive as its
  # default — never nil. The required, defaultless field keeps its own presence rule,
  # proving the coercion is scoped to defaulted attributes only.
  class DefaultedNumericDouble < Base
    attribute :required_amount, :decimal
    attribute :offset, :integer, default: 3
    attribute :factor, :decimal, default: 2

    validates :required_amount, presence: true

    private

    def compute = { total: required_amount * factor + (offset * 12) }
  end
end
