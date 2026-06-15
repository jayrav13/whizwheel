module Admin
  # The site-wide usage dashboard (/admin/stats). ADMIN-gated via Admin::BaseController.
  # Exposes the stable `@stats` query object the frontend (#221) renders against —
  # the view calls only its documented methods (CalculationStats).
  class StatsController < BaseController
    def show
      @stats = CalculationStats.new
    end
  end
end
