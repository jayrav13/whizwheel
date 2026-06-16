require "test_helper"

# Unit test for HomeHelper#catalog_calculators — the thin read-only registry query that
# drives the home catalog grid (issue #107). Ruby helpers are coverage-counted
# (ARCHITECTURE.md §11).
class HomeHelperTest < ActionView::TestCase
  test "catalog_calculators returns the active calculators, deprecated excluded" do
    slugs = catalog_calculators.map(&:slug)
    assert_includes slugs, "percentage"
    assert_includes slugs, "tip"
    # The deprecated fixture row never appears in the catalog.
    assert_not_includes slugs, "retired_thing"
  end

  test "catalog_calculators orders by category then name" do
    ordered = catalog_calculators.to_a
    sorted = ordered.sort_by { |c| [ c.category, c.name ] }
    assert_equal sorted.map(&:slug), ordered.map(&:slug)
  end

  # #calculator_page_ready? — the card-link gate for issue #214. True when the calculator's
  # show page template exists; false during the backend-before-frontend window when only the
  # registry row exists. Both branches are exercised (Ruby helpers are coverage-counted, §11).
  test "calculator_page_ready? is true for a page-backed calculator" do
    # Every fixture calculator with a slug also has app/views/calculators/<slug>.html.erb.
    assert calculator_page_ready?(calculators(:tip))
    assert calculator_page_ready?(calculators(:percentage))
  end

  test "calculator_page_ready? is false for a calculator with no page yet" do
    # A registry row whose slug has no app/views/calculators/<slug>.html.erb — the exact
    # backend-before-frontend state that would 500 if the catalog linked to it.
    pageless = Calculator.new(slug: "no_such_calculator_page", name: "Pending Calculator", category: "Math")
    assert_not calculator_page_ready?(pageless)
  end
end
