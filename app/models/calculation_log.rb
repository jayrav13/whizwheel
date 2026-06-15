# Read-only AR model backed by the `calculation_logs` DB view (ARCHITECTURE.md §5):
# a denormalized join of `calculations ⨝ users` that surfaces `username` for
# reporting. The view is the read model for site-wide stats; writes go through
# `Calculation`. The view also selects `deleted_at` so site-wide stats
# (CalculationStats) can count the FULL table — discarded rows INCLUDED — per
# §6: usage is usage, so a user soft-deleting their own history hides it from
# their view but never erodes site-wide totals.
class CalculationLog < ApplicationRecord
  self.table_name = "calculation_logs"

  # A view is not writable through AR; make that explicit.
  def readonly? = true
end
