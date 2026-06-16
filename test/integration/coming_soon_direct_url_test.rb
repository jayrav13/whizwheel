require "test_helper"
require_relative "../support/calculators"

# Issue #214 — the BACKEND half of "a registry-active calculator with no page must not
# 500." The frontend gated each catalog card's LINK on the page existing, but a DIRECT URL
# hit (a bookmark, a shared link, a crawler) still reaches CalculatorsController#show — and
# without the rescue, `render "calculators/<slug>"` raises ActionView::MissingTemplate → a
# user-facing 500. The controller now degrades exactly that one missing page into the
# on-brand "coming soon" fallback (calculators/unavailable) with a soft 200.
#
# These tests drive the FULL integration stack (a real GET through routing → the controller
# → the real app/views/calculators/unavailable.html.erb), unlike the functional test, which
# prepends a stub view path. NumericGuardDouble is a genuine Calculators::X constant with NO
# app view — exactly the backend-before-frontend window.
class ComingSoonDirectUrlTest < ActionDispatch::IntegrationTest
  test "a direct GET to a registry-active, page-less calculator renders the fallback (200), not a 500" do
    get "/calculators/numeric_guard_double"

    assert_response :success # soft 200 — the calculator exists; only its page is unbuilt.
    assert_select "p.text-accent", text: "Coming soon"
    # The fallback resolves a human name from the slug (no registry row → titleized).
    assert_select "h1", text: "Numeric Guard Double"
    assert_match(/being built/i, @response.body)
    # A catalog link is the only affordance — there is no result UI / form to compute.
    assert_select "a[href=?]", root_path, text: "Browse all calculators"
  end

  test "the fallback prefers the registry's curated name when a row exists for the slug" do
    Calculator.create!(slug: "numeric_guard_double", name: "Numeric Guard", category: "Math",
                       description: "Pending its page.")

    get "/calculators/numeric_guard_double"

    assert_response :success
    assert_select "h1", text: "Numeric Guard"
  end

  test "an unknown slug is still a 404 (the rescue does not turn 404s into the fallback)" do
    get "/calculators/no_such_calculator"
    assert_response :not_found
  end
end
