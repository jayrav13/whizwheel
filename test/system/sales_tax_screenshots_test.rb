require "application_system_test_case"

# Drives the real browser through the Sales Tax page's key states and saves a full-page
# screenshot of each (issue #252) — a solve-for-X calculator over the before-tax price, the tax
# rate, and the after-tax price. Doubles as a Turbo/Stimulus regression check (the form posts
# over Turbo and the #result fragment updates in place; the sales_tax_controller reveals only the
# active mode's two fields and swaps the helper line) and a visual artifact reviewed against
# docs/DESIGN.md (CI uploads the PNGs). Structural twin of VAT (#255) — keep parallel.
class SalesTaxScreenshotsTest < ApplicationSystemTestCase
  test "empty result before any submission, with after mode's two fields shown" do
    visit "/calculators/sales_tax"
    assert_selector "h1", text: "Sales Tax Calculator"
    # Default mode is "after" → before-tax price + rate are shown; after-tax price is hidden
    # (the field that mode solves for). Assert visibility on the input ids directly.
    assert_selector "input#inputs_before_tax_price", visible: true
    assert_selector "input#inputs_rate", visible: true
    assert_no_selector "input#inputs_after_tax_price", visible: true
    assert_text "your answer appears here"
    screenshot_full_page("sales-tax-01-default")
  end

  test "switching to before mode reveals the after-tax-price field and hides the before field" do
    visit "/calculators/sales_tax"
    # The segmented control is a native radio with a visually-hidden (sr-only) radio, so click
    # the label; choosing "Before-tax price" re-gates which two fields are given.
    choose "Before-tax price", allow_label_click: true
    assert_selector "input#inputs_after_tax_price", visible: true
    assert_selector "input#inputs_rate", visible: true
    assert_no_selector "input#inputs_before_tax_price", visible: true
    screenshot_full_page("sales-tax-02-before-mode")
  end

  test "switching to rate mode reveals both price fields and hides the rate field" do
    visit "/calculators/sales_tax"
    choose "Tax rate", allow_label_click: true
    assert_selector "input#inputs_before_tax_price", visible: true
    assert_selector "input#inputs_after_tax_price", visible: true
    assert_no_selector "input#inputs_rate", visible: true
    screenshot_full_page("sales-tax-03-rate-mode")
  end

  test "computes the after-tax price and renders the hero, stat grid and breakdown" do
    visit "/calculators/sales_tax"
    fill_in "Before-tax price", with: "100"
    fill_in "Tax rate", with: "6"
    click_button "Calculate"
    # Turbo replaced #result in place — the solved figure + figures appear without a reload.
    within "#result" do
      # The eyebrow labels are uppercased by CSS, so the rendered text is upper-case.
      assert_text "AFTER-TAX PRICE"
      assert_text "$106.00"   # after-tax price (the hero)
      assert_text "$6.00"     # tax amount
      assert_text "BREAKDOWN"
    end
    screenshot_full_page("sales-tax-04-after-result")
  end

  test "computes the tax rate from two prices" do
    visit "/calculators/sales_tax"
    choose "Tax rate", allow_label_click: true
    fill_in "Before-tax price", with: "100"
    fill_in "After-tax price", with: "106"
    click_button "Calculate"
    within "#result" do
      assert_text "TAX RATE"
      assert_text "6.0000%"   # solved rate (the hero)
      assert_text "$6.00"     # tax amount
    end
    screenshot_full_page("sales-tax-05-rate-result")
  end

  test "a high-magnitude price renders the wide stat grid on one line without clipping" do
    # A 7-digit price ($1,000,000.00) is the exact case the --wide track exists for. Prove the
    # worst-case figures hold on one line and never clip in the narrow result panel.
    visit "/calculators/sales_tax"
    fill_in "Before-tax price", with: "1000000"
    fill_in "Tax rate", with: "8.25"
    click_button "Calculate"
    within "#result" do
      assert_text "$1,082,500.00"  # after-tax price
      assert_text "$82,500.00"     # tax amount
    end
    assert_no_mid_value_wrap("#result dl.stat-grid--wide .stat-card dd")
    assert_no_value_clip("#result dl.stat-grid--wide .stat-card dd")
    screenshot_full_page("sales-tax-06-large-result")
  end

  test "segmented mode pills are equal height with vertically-centered text when labels wrap" do
    # The reported bug (operator screenshot): with "Tax rate" selected, the one-line "Tax rate"
    # pill's text was top-pinned against the taller, wrap-determined height of the two-line
    # "After-tax price" / "Before-tax price" pills. Narrow the window so the segmented track is
    # tight enough that the multi-word labels WRAP to two lines, then assert every pill is equal
    # height and its text is vertically centered — in BOTH the default state and with "Tax rate"
    # selected (the exact reported state).
    page.driver.browser.manage.window.resize_to(420, 900)
    visit "/calculators/sales_tax"
    assert_selector ".direction-pill", minimum: 3
    assert_pills_equal_height_and_centered(".direction-pill")
    screenshot_full_page("sales-tax-08-pills-wrap-default")

    choose "Tax rate", allow_label_click: true
    assert_pills_equal_height_and_centered(".direction-pill")
    screenshot_full_page("sales-tax-09-pills-wrap-rate-selected")
  end

  test "invalid input shows the error fragment" do
    visit "/calculators/sales_tax"
    # Submit with no numbers → server 422 → error fragment in #result.
    click_button "Calculate"
    within "#result" do
      # The eyebrow is uppercased by CSS, so the rendered text is "CHECK YOUR INPUT".
      assert_text "CHECK YOUR INPUT"
      assert_selector "[role=alert] li", text: "Before-tax price can't be blank"
    end
    screenshot_full_page("sales-tax-07-error")
  end
end
