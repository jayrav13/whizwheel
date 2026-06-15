# Read-only AR model backed by the `calculation_logs` DB view (ARCHITECTURE.md §5):
# a denormalized join of `calculations ⨝ users` that surfaces `username` for
# reporting. The view is the read model for site-wide stats; writes go through
# `Calculation`. Stats queries (CalculationStats) read THIS, always filtering
# `deleted_at IS NULL` to respect soft-delete (§6). Site-wide stats count all
# users' kept rows — a user hiding their own history never erodes site totals.
class CalculationLog < ApplicationRecord
  self.table_name = "calculation_logs"

  # A view is not writable through AR; make that explicit.
  def readonly? = true
end
