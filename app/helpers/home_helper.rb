# Home-page view helpers. The catalog card grid is driven by the derived calculator
# registry (CLAUDE.md → "The calculator registry") rather than hand-edited cards, so
# adding a calculator no longer touches home/index.html.erb (issue #107). This is a
# read-only display query — within the frontend's remit (it adds no controller business
# logic and does not touch the model).
module HomeHelper
  # The active (non-deprecated) calculators for the catalog, grouped sensibly: by category
  # then name, so the grid reads as an alphabetical-by-section library. The card renders the
  # registry metadata — category eyebrow, name, description blurb — and links to the
  # calculator's page by slug.
  def catalog_calculators
    Calculator.active.order(:category, :name)
  end
end
