require "test_helper"

# Issue #214 — renders the generic coming-soon fallback template directly
# (calculators/unavailable.html.erb), the stable path the backend follow-up's
# `rescue_from ActionView::MissingTemplate` will render. There is no GET route to it until
# that backend rescue lands, so we render the template in a view-test context to prove its
# ERB and its name resolution. A view-render test exercises the real template + helpers
# (CalculatorsHelper is auto-included by ActionView::TestCase for this view path).
class ComingSoonFallbackViewTest < ActionView::TestCase
  tests CalculatorsHelper

  test "renders the calculator's curated name, the coming-soon eyebrow, and a catalog link" do
    # The controller sets @calculator to the looked-up Calculators::X class.
    @calculator = Calculators::Base.lookup("tip")
    render template: "calculators/unavailable", layout: false

    assert_select "p.text-accent.uppercase", text: "Coming soon"
    # The registry's curated human name, resolved from the slug.
    assert_select "h1", text: "Tip Calculator"
    assert_match(/being built/i, rendered)
    # A coral primary button back to the catalog — the only affordance (no result UI).
    assert_select "a[href=?]", root_path, text: "Browse all calculators"
  end

  test "falls back to a titleized slug when the registry has no row for the class" do
    # A calculator class on `main` before its INVENTORY row is ingested — no Calculator row.
    @calculator = Calculators::Base.lookup("right_triangle")
    Calculator.where(slug: "right_triangle").delete_all
    render template: "calculators/unavailable", layout: false

    assert_select "h1", text: "Right Triangle"
  end

  test "degrades gracefully when no @calculator is assigned" do
    # Defensive: a future caller may render the fallback with no looked-up class.
    @calculator = nil
    render template: "calculators/unavailable", layout: false

    assert_select "h1", text: "This calculator"
    assert_select "p.text-accent.uppercase", text: "Coming soon"
  end
end
