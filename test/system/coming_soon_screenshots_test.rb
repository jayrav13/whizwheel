require "application_system_test_case"

# Issue #214 — the browser-driven visual review for the coming-soon catalog state. A
# registry-active calculator with no page yet renders as a non-linked "Coming soon" card
# in the home catalog (the backend-before-frontend window), so the catalog never links to a
# 500ing page. Drives the real browser and saves a full-page screenshot for the visual gate.
#
# The generic fallback PAGE (calculators/unavailable.html.erb) has no GET route until the
# backend rescue_from lands, so it isn't browser-reachable here — its markup is covered by
# ComingSoonFallbackViewTest (a view-render test). This shot covers the user-facing surface
# that IS reachable today: the catalog's coming-soon card.
class ComingSoonScreenshotsTest < ApplicationSystemTestCase
  test "home catalog shows a non-linked Coming soon card for a not-yet-built calculator" do
    # An active registry row whose slug has no page — the exact backend-before-frontend state.
    Calculator.create!(slug: "pending_widget", name: "Pending Widget", category: "Math",
                       description: "A calculator whose page has not shipped yet.")

    visit root_path

    # The Coming soon card paints with its name + badge, and is NOT a link. The badge is
    # rendered uppercase via CSS (text-transform), so Capybara's visible-text matcher sees
    # "COMING SOON" — match the displayed form.
    assert_selector "div[aria-disabled='true']", text: "Pending Widget"
    assert_selector "div[aria-disabled='true']", text: /COMING SOON/i
    assert_no_selector "a[href='/calculators/pending_widget']"

    # Sanity: a real, page-backed calculator still renders as a live link beside it.
    assert_selector "a[href='/calculators/tip']", text: "Tip Calculator"

    screenshot_full_page("05-home-coming-soon-card")
  end
end
