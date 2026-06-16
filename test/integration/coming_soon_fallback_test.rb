require "test_helper"

# Issue #214 — the frontend half of "a registry-active calculator with no page must not
# 500." A calculator becomes registry-active the moment its backend Calculators::X class
# and its catalog row land, which can precede its frontend page by a full PR. Two frontend
# guards close the user-facing gap:
#
#   1. The home catalog gates each card's LINK on the page existing (HomeHelper#calculator_page_ready?)
#      — a not-yet-built calculator renders as a non-linked "Coming soon" card, so the
#      catalog never links to a 500ing page.
#   2. A generic "coming soon" fallback page (calculators/unavailable.html.erb) the backend
#      follow-up renders for the direct-URL case (its rescue_from MissingTemplate).
#
# This test exercises the catalog gating end-to-end. The fallback view's own render is
# covered by ComingSoonFallbackViewTest (a view-render test) — there is no route to GET it
# until the backend rescue lands, so it can't be reached through the integration stack here.
class ComingSoonFallbackTest < ActionDispatch::IntegrationTest
  test "a page-backed calculator renders a live catalog link" do
    get root_path
    assert_response :success
    # Tip has app/views/calculators/tip.html.erb — a real, clickable link.
    assert_select "a[href=?]", "/calculators/tip", { count: 1 } do
      assert_select "h2", text: "Tip Calculator"
    end
  end

  test "a registry-active calculator with no page renders a non-linked Coming soon card" do
    # Simulate the backend-before-frontend window: an active registry row whose slug has no
    # app/views/calculators/<slug>.html.erb. (Inline, so the broad catalog tests — which
    # assume every fixture calculator is page-backed — stay green.)
    pending = Calculator.create!(slug: "pending_widget", name: "Pending Widget", category: "Math",
                                 description: "A calculator whose page has not shipped yet.")

    get root_path
    assert_response :success

    # No live link to the not-yet-built page (the 500 path is never offered).
    assert_select "a[href=?]", "/calculators/#{pending.slug}", { count: 0 }

    # Instead, a non-linked Coming soon card — its name + description still surface, with an
    # explicit "Coming soon" badge so the state never rests on colour alone (DESIGN.md §6).
    assert_select "div[aria-disabled=true]" do
      assert_select "h2", text: "Pending Widget"
      assert_select "p", text: "A calculator whose page has not shipped yet."
      assert_select "p", text: "Coming soon"
    end
  end

  test "the coming-soon card never emits a link to its slug" do
    Calculator.create!(slug: "pending_widget", name: "Pending Widget", category: "Math",
                       description: "Not shipped yet.")
    get root_path
    assert_response :success
    # Defense in depth: the slug must not appear in ANY href (no partial/hidden link).
    assert_select "a[href*='pending_widget']", { count: 0 }
  end
end
