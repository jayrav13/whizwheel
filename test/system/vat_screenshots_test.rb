require "application_system_test_case"

# Drives the real browser through the VAT page's key states and saves a full-page screenshot of
# each (issue #255) — a solve-for-X value-added-tax calculator over net price / VAT rate / gross
# price, in three modes. Doubles as a Turbo/Stimulus regression check (the form posts over Turbo
# and the #result fragment updates in place; the vat_controller reveals only the active mode's
# two given fields) and a visual artifact reviewed against docs/DESIGN.md (CI uploads the PNGs).
#
# Deliberate structural twin of the Sales Tax screenshots test (net/VAT/gross ↔ before/tax/after).
class VatScreenshotsTest < ApplicationSystemTestCase
  test "empty result before any submission, with gross mode's given fields shown" do
    visit "/calculators/vat"
    assert_selector "h1", text: "VAT Calculator"
    # Default mode is "gross" → it is GIVEN net price + rate, and solves for gross. So net price
    # and rate are shown; gross price (the solved-for field) is hidden.
    assert_selector "input#inputs_net_price", visible: true
    assert_selector "input#inputs_rate", visible: true
    assert_no_selector "input#inputs_gross_price", visible: true
    assert_text "your answer appears here"
    screenshot_full_page("90-vat-default")
  end

  test "switching to net mode reveals the gross-price field and hides the net-price field" do
    visit "/calculators/vat"
    # The mode picker is a native radio segmented control with a visually-hidden (sr-only) radio,
    # so click the label; choosing "Net price" re-gates which two fields are shown. The mode
    # label "Net price" collides with the field label, so assert visibility on the input ids.
    choose "Net price", allow_label_click: true
    assert_selector "input#inputs_gross_price", visible: true
    assert_selector "input#inputs_rate", visible: true
    assert_no_selector "input#inputs_net_price", visible: true
    screenshot_full_page("91-vat-net-mode")
  end

  test "switching to rate mode reveals net + gross and hides the rate field" do
    visit "/calculators/vat"
    choose "VAT rate", allow_label_click: true
    assert_selector "input#inputs_net_price", visible: true
    assert_selector "input#inputs_gross_price", visible: true
    assert_no_selector "input#inputs_rate", visible: true
    screenshot_full_page("92-vat-rate-mode")
  end

  test "gross mode computes and renders the hero, stat grid and breakdown" do
    visit "/calculators/vat"
    fill_in "Net price", with: "10"
    fill_in "VAT rate", with: "10"
    click_button "Calculate"
    # Turbo replaced #result in place — the solved gross-price hero + figures appear without a
    # reload.
    within "#result" do
      # The eyebrow labels are uppercased by CSS, so the rendered text is upper-case.
      assert_text "GROSS PRICE"
      assert_text "$11.00"  # gross price (the hero)
      assert_text "$1.00"   # VAT amount
      assert_text "BREAKDOWN"
    end
    screenshot_full_page("93-vat-gross-result")
  end

  test "net mode solves the net price from a gross price and rate" do
    visit "/calculators/vat"
    choose "Net price", allow_label_click: true
    fill_in "Gross price", with: "11"
    fill_in "VAT rate", with: "10"
    click_button "Calculate"
    within "#result" do
      assert_text "$10.00"  # net price (the hero)
      assert_text "$1.00"   # VAT amount
    end
    screenshot_full_page("94-vat-net-result")
  end

  test "rate mode solves the VAT rate from a net and gross price" do
    visit "/calculators/vat"
    choose "VAT rate", allow_label_click: true
    fill_in "Net price", with: "10"
    fill_in "Gross price", with: "11"
    click_button "Calculate"
    within "#result" do
      assert_text "10%"     # solved VAT rate (the hero)
      assert_text "$1.00"   # VAT amount
    end
    screenshot_full_page("95-vat-rate-result")
  end

  test "a high-magnitude price renders the wide stat grid on one line without clipping" do
    # A 7-digit price is the exact case the --wide track exists for. Prove the worst-case figures
    # hold on one line and never clip in the narrow result panel: net $1,000,000 @ 10% → gross
    # $1,100,000.00, vat $100,000.00.
    visit "/calculators/vat"
    fill_in "Net price", with: "1000000"
    fill_in "VAT rate", with: "10"
    click_button "Calculate"
    within "#result" do
      assert_text "$1,000,000.00"  # net price
      assert_text "$1,100,000.00"  # gross price
      assert_text "$100,000.00"    # VAT amount
    end
    assert_no_mid_value_wrap("#result dl.stat-grid--wide .stat-card dd")
    assert_no_value_clip("#result dl.stat-grid--wide .stat-card dd")
    screenshot_full_page("96-vat-large-result")
  end

  test "invalid input shows the error fragment" do
    visit "/calculators/vat"
    # Submit with no numbers → server 422 → error fragment in #result.
    click_button "Calculate"
    within "#result" do
      # The eyebrow is uppercased by CSS, so the rendered text is "CHECK YOUR INPUT".
      assert_text "CHECK YOUR INPUT"
      assert_selector "[role=alert] li", text: "Net price can't be blank"
    end
    screenshot_full_page("97-vat-error")
  end
end
