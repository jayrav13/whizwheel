require "application_system_test_case"

# Drives the real browser through the ROI calculator page's key states and saves a full-page
# screenshot of each (issue #258). The states that matter here: a GAIN (ROI % hero in accent
# green + the annualized figure), a LOSS (signed negative ROI in coral), break-even, a live
# direction-preview chip (the roi Stimulus controller), and the worst-case 7-figure money in
# the stat grid (which must never clip). Doubles as a visual artifact reviewed against
# docs/DESIGN.md (CI uploads the PNGs).
class RoiScreenshotsTest < ApplicationSystemTestCase
  test "default empty state" do
    visit "/calculators/roi"
    assert_selector "h1", text: "ROI Calculator"
    assert_text "your answer appears here"
    # The optional period is present but blank (never auto-prefilled).
    assert_field "inputs[investment_years]", with: ""
    screenshot_full_page("90-roi-default")
  end

  test "the live direction-preview chip reads Gain as the user types" do
    visit "/calculators/roi"
    fill_in "inputs[amount_invested]", with: "50000"
    fill_in "inputs[amount_returned]", with: "70000"
    # The Stimulus preview chip lights up once both money fields hold a value (the chip text
    # is uppercased by CSS, so the visible text is "GAIN").
    assert_selector "[data-roi-target='preview']", text: "GAIN"
    screenshot_full_page("91-roi-preview-gain")
  end

  test "computing a gain with a period shows the ROI and annualized figures over Turbo" do
    visit "/calculators/roi"
    fill_in "inputs[amount_invested]", with: "50000"
    fill_in "inputs[amount_returned]", with: "70000"
    fill_in "inputs[investment_years]", with: "5"
    click_button "Calculate"
    within "#result" do
      assert_text "40.0000"   # ROI %
      assert_text "6.9610"    # annualized ROI %
      assert_text "GAIN"      # the sign tag, uppercased by the eyebrow CSS
      assert_text "Annualized ROI"
      assert_text "20,000.00" # total gain
    end
    screenshot_full_page("92-roi-gain-result")
  end

  test "computing without a period omits the annualized figure" do
    visit "/calculators/roi"
    fill_in "inputs[amount_invested]", with: "50000"
    fill_in "inputs[amount_returned]", with: "70000"
    click_button "Calculate"
    within "#result" do
      assert_text "40.0000"
      assert_no_text "Annualized ROI"
    end
    screenshot_full_page("93-roi-no-period")
  end

  test "a loss renders a signed negative ROI in coral, tagged Loss" do
    visit "/calculators/roi"
    fill_in "inputs[amount_invested]", with: "10000"
    fill_in "inputs[amount_returned]", with: "8000"
    click_button "Calculate"
    within "#result" do
      assert_text "-20.0000"
      assert_text "LOSS"   # the sign tag, uppercased by the eyebrow CSS
    end
    screenshot_full_page("94-roi-loss")
  end

  test "a break-even result reads in neutral ink" do
    visit "/calculators/roi"
    fill_in "inputs[amount_invested]", with: "1000"
    fill_in "inputs[amount_returned]", with: "1000"
    click_button "Calculate"
    within "#result" do
      assert_text "0.0000"
      # The tag sits in the uppercased eyebrow, so the rendered text is "BREAK-EVEN".
      assert_text "BREAK-EVEN"
    end
    screenshot_full_page("95-roi-break-even")
  end

  test "a 7-figure money value fills the wide stat grid without clipping or wrapping mid-number" do
    visit "/calculators/roi"
    fill_in "inputs[amount_invested]", with: "1000000"
    fill_in "inputs[amount_returned]", with: "1500000"
    click_button "Calculate"
    within "#result" do
      assert_text "1,000,000.00" # invested, delimited, in full
      assert_text "500,000.00"   # gain
      assert_text "1,500,000.00" # returned
    end
    # The big tabular-nums money figures must NOT clip at the card edge (DESIGN.md §4: stats
    # must NEVER clip), and the `--wide` track must hold them on a single line (no mid-number
    # wrap). A text assertion can't see a clip/wrap — measure the laid-out geometry.
    assert_no_value_clip("#result dl.stat-grid .stat-card dd")
    assert_no_mid_value_wrap("#result dl.stat-grid .stat-card dd")
    screenshot_full_page("96-roi-large")
  end

  test "an invalid input shows the label-based error fragment" do
    visit "/calculators/roi"
    fill_in "inputs[amount_invested]", with: "0"
    fill_in "inputs[amount_returned]", with: "100"
    click_button "Calculate"
    within "#result" do
      # The eyebrow is uppercased by CSS, so the rendered text is "CHECK YOUR INPUT".
      assert_text "CHECK YOUR INPUT"
      assert_selector "[role=alert] li", text: /Amount invested must be greater than 0/
    end
    screenshot_full_page("97-roi-error")
  end
end
