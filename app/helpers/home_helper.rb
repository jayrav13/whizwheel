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

  # Whether a calculator's show page has actually shipped (issue #214). A calculator
  # becomes registry-active the moment its backend `Calculators::X` class lands and its
  # slug appears in the catalog — which can precede its frontend page by a full PR (the
  # backend-before-frontend merge window). During that window
  # `app/views/calculators/<slug>.html.erb` does not yet exist, so a live catalog link
  # would 500 (ActionView::MissingTemplate). The catalog card gates its link on this:
  # page-backed → a live link; not-yet-built → a non-linked "Coming soon" card. View
  # existence is the same convention the result dispatch uses
  # (CalculatorsHelper#calculator_result_partial) and mirrors the backend's
  # no-central-registration rule — no shared file is edited to register a page.
  def calculator_page_ready?(calculator)
    lookup_context.exists?("calculators/#{calculator.slug}", [], false)
  end
end
