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
end
