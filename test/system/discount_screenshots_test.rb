require "application_system_test_case"

# Drives the real browser through the Discount page's key states and saves a full-page
# screenshot of each (issue #254) — an original price with a percent-off or fixed-amount-off
# discount. Doubles as a Turbo/Stimulus regression check (the form posts over Turbo and the
# #result fragment updates in place; the discount_controller reveals only the active mode's
# discount field) and a visual artifact reviewed against docs/DESIGN.md (CI uploads the PNGs).
class DiscountScreenshotsTest < ApplicationSystemTestCase
  test "empty result before any submission, with percent mode's field shown" do
    visit "/calculators/discount"
    assert_selector "h1", text: "Discount Calculator"
    # Default mode is "percent" → original price + percent off are shown; amount off is hidden
    # (the fixed mode's field). The mode-option label "Percent off" collides with the field
    # label, so assert field visibility on the input id directly.
    assert_selector "input#inputs_original_price", visible: true
    assert_selector "input#inputs_percent_off", visible: true
    assert_no_selector "input#inputs_amount_off", visible: true
    assert_text "your answer appears here"
    screenshot_full_page("70-discount-default")
  end

  test "switching to fixed mode reveals the amount-off field and hides percent off" do
    visit "/calculators/discount"
    # The mode picker is a native radio option list with a visually-hidden (sr-only) radio, so
    # click the label; choosing "Fixed amount off" re-gates the discount field.
    choose "Fixed amount off", allow_label_click: true
    assert_selector "input#inputs_original_price", visible: true
    assert_selector "input#inputs_amount_off", visible: true
    assert_no_selector "input#inputs_percent_off", visible: true
    screenshot_full_page("71-discount-fixed-mode")
  end

  test "computes a percent-off discount and renders the hero, stat grid and breakdown" do
    visit "/calculators/discount"
    fill_in "Original price", with: "45"
    fill_in "Percent off", with: "10"
    click_button "Calculate"
    # Turbo replaced #result in place — the final-price hero + figures appear without a reload.
    within "#result" do
      # The eyebrow labels are uppercased by CSS, so the rendered text is upper-case.
      assert_text "FINAL PRICE"
      assert_text "$40.50"  # final price (the hero)
      assert_text "$4.50"   # amount saved
      assert_text "BREAKDOWN"
    end
    screenshot_full_page("72-discount-percent-result")
  end

  test "computes a fixed-amount discount" do
    visit "/calculators/discount"
    choose "Fixed amount off", allow_label_click: true
    fill_in "Original price", with: "80"
    fill_in "Amount off", with: "15"
    click_button "Calculate"
    within "#result" do
      assert_text "$65.00"  # final price (the hero)
      assert_text "$15.00"  # amount saved
    end
    screenshot_full_page("73-discount-fixed-result")
  end

  test "a high-magnitude price renders the wide stat grid on one line without clipping" do
    # A 7-digit price ($1,000,000.00) is the exact case the --wide track exists for. Prove the
    # worst-case figures hold on one line and never clip in the narrow result panel.
    visit "/calculators/discount"
    fill_in "Original price", with: "1000000"
    fill_in "Percent off", with: "25"
    click_button "Calculate"
    within "#result" do
      assert_text "$750,000.00"  # final price
      assert_text "$250,000.00"  # amount saved
    end
    assert_no_mid_value_wrap("#result dl.stat-grid--wide .stat-card dd")
    assert_no_value_clip("#result dl.stat-grid--wide .stat-card dd")
    screenshot_full_page("74-discount-large-result")
  end

  test "invalid input shows the error fragment" do
    visit "/calculators/discount"
    # Submit with no numbers → server 422 → error fragment in #result.
    click_button "Calculate"
    within "#result" do
      # The eyebrow is uppercased by CSS, so the rendered text is "CHECK YOUR INPUT".
      assert_text "CHECK YOUR INPUT"
      assert_selector "[role=alert] li", text: "Original price can't be blank"
    end
    screenshot_full_page("75-discount-error")
  end
end
