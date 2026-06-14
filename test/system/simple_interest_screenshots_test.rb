require "application_system_test_case"

# Drives the real browser through the Simple Interest page's key states and saves a
# full-page screenshot of each (issue #78). Doubles as a Turbo/Stimulus regression check
# (the form submits over Turbo and the #result fragment updates in place; the Stimulus
# controller lifts the active unit half) and a visual artifact reviewed against
# docs/DESIGN.md (CI uploads the PNGs).
class SimpleInterestScreenshotsTest < ApplicationSystemTestCase
  test "default state with empty result" do
    visit "/calculators/simple_interest"
    assert_selector "h1", text: "Simple Interest Calculator"
    # The unit picker is the two-option segmented control (Years default | Months).
    assert_selector "label.direction-pill", text: "Years"
    assert_selector "label.direction-pill", text: "Months"
    assert_field "Principal"
    assert_field "Annual rate"
    assert_field "Time"
    assert_text "your answer appears here"
    screenshot_full_page("40-simple-interest-default")
  end

  test "computes a years calculation and renders the hero result over Turbo" do
    visit "/calculators/simple_interest"
    fill_in "Principal", with: "1000"
    fill_in "Annual rate", with: "5"
    fill_in "Time", with: "3"
    click_button "Calculate"
    # Turbo replaced #result in place — the hero balance + breakdown appear without a reload.
    within "#result" do
      # The eyebrow is uppercased by CSS, so the rendered text is "ENDING BALANCE".
      assert_text "ENDING BALANCE"
      assert_text "1,150.00"
      assert_text "150.00"
    end
    screenshot_full_page("41-simple-interest-result")
  end

  test "months mode converts to years before computing" do
    visit "/calculators/simple_interest"
    fill_in "Principal", with: "2000"
    fill_in "Annual rate", with: "6"
    fill_in "Time", with: "18"
    choose "Months", allow_label_click: true
    click_button "Calculate"
    within "#result" do
      assert_text "2,180.00"
      assert_text "180.00"
    end
    screenshot_full_page("42-simple-interest-months")
  end

  test "a six-plus-digit result lays out in the stat grid without clipping" do
    visit "/calculators/simple_interest"
    fill_in "Principal", with: "1000000"
    fill_in "Annual rate", with: "8"
    fill_in "Time", with: "10"
    click_button "Calculate"
    within "#result" do
      # 1,000,000 @ 8% for 10 years → 800,000.00 interest, 1,800,000.00 ending balance.
      assert_text "1,800,000.00"
      assert_text "800,000.00"
      assert_text "1,000,000.00"
    end
    screenshot_full_page("44-simple-interest-large")
  end

  test "invalid input shows the error fragment" do
    visit "/calculators/simple_interest"
    # Submit with no numbers → server 422 → error fragment in #result.
    click_button "Calculate"
    within "#result" do
      # The eyebrow is uppercased by CSS, so the rendered text is "CHECK YOUR INPUT".
      assert_text "CHECK YOUR INPUT"
      assert_selector "[role=alert] li", text: "Principal can't be blank"
      assert_selector "[role=alert] li", text: "Time can't be blank"
    end
    screenshot_full_page("43-simple-interest-error")
  end
end
