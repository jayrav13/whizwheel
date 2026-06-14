require "application_system_test_case"

# Drives the real browser through the Amortization page's key states and saves a
# full-page screenshot of each (issue #84) — the project's first tabular-output + charts
# page, so the visual review matters most here. Doubles as a Turbo/Stimulus regression
# check (the form posts over Turbo and the #result fragment updates in place; the
# amortization_controller paginates the long schedule and the "Show all" button reveals
# the rest) and a visual artifact reviewed against docs/DESIGN.md (CI uploads the PNGs).
class AmortizationScreenshotsTest < ApplicationSystemTestCase
  test "empty result before any submission" do
    visit "/calculators/amortization"
    assert_selector "h1", text: "Amortization Calculator"
    assert_field "Loan amount"
    assert_field "Annual interest rate"
    assert_field "Loan term"
    assert_text "your answer appears here"
    screenshot_full_page("30-amortization-default")
  end

  test "computes a 30-year mortgage and renders the hero, charts and paginated schedule" do
    visit "/calculators/amortization"
    fill_in "Loan amount", with: "100000"
    fill_in "Annual interest rate", with: "6"
    fill_in "Loan term", with: "30"
    click_button "Calculate"
    # Turbo replaced #result in place — the hero payment + totals appear without a reload.
    within "#result" do
      assert_text "599.55"           # monthly payment
      assert_text "215,838.45"       # total of payments
      assert_text "115,838.45"       # total interest
      # The chart eyebrows are uppercased by CSS, so the rendered text is upper-case.
      assert_text "WHERE YOUR MONEY GOES"
      assert_text "BALANCE OVER TIME"
      # Stimulus paginates: the first page of rows shows; the rest are hidden until
      # "Show all". Month 1 is visible; a far-out month (e.g. 200) is not, yet.
      assert_selector "tbody tr:not([hidden])", count: 12
      assert_text "Show all"
    end
    screenshot_full_page("31-amortization-result")
  end

  test "Show all reveals the full schedule" do
    visit "/calculators/amortization"
    fill_in "Loan amount", with: "10000"
    fill_in "Annual interest rate", with: "4.5"
    fill_in "Loan term", with: "5"
    click_button "Calculate"
    within "#result" do
      assert_text "186.43" # monthly payment
      click_button "Show all 60 months"
      # All 60 rows now visible; the final row reads "Paid off" (balance 0.00).
      assert_selector "tbody tr:not([hidden])", count: 60
      assert_text "Paid off"
    end
    screenshot_full_page("32-amortization-full-schedule")
  end

  test "invalid input shows the error fragment" do
    visit "/calculators/amortization"
    # Submit with no numbers → server 422 → error fragment in #result.
    click_button "Calculate"
    within "#result" do
      # The eyebrow is uppercased by CSS, so the rendered text is "CHECK YOUR INPUT".
      assert_text "CHECK YOUR INPUT"
      assert_selector "[role=alert] li", text: "Loan amount can't be blank"
    end
    screenshot_full_page("33-amortization-error")
  end
end
