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
end
