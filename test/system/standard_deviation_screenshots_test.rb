require "application_system_test_case"

# Drives the real browser through the Standard Deviation page's key states and saves a
# full-page screenshot of each (frontend issue #191; spec #190). Doubles as a Turbo
# regression check (the form posts over Turbo and the #result fragment updates in place;
# there is no Stimulus here — the mode picker is a no-JS-safe segmented radio) and a visual
# artifact reviewed against docs/DESIGN.md (CI uploads the PNGs). The variable-length list
# input, the population/sample segmented picker, and the never-clip geometry on large
# unit-less statistics are the things this calculator stresses.
class StandardDeviationScreenshotsTest < ApplicationSystemTestCase
  test "default empty state with the list input and mode picker" do
    visit "/calculators/standard_deviation"
    assert_selector "h1", text: "Standard Deviation Calculator"
    assert_field "Values"
    assert_text "your answer appears here"
    screenshot_full_page("60-std-dev-default")
  end

  test "a population-mode list renders the standard deviation and supporting stats" do
    visit "/calculators/standard_deviation"
    fill_in "Values", with: "10, 12, 23, 23, 16, 23, 21, 16"
    choose "Population", allow_label_click: true
    click_button "Calculate"
    within "#result" do
      assert_text "4.898979"  # standard deviation (hero)
      assert_text "Population standard deviation"
      assert_text "24"        # variance
      assert_text "18"        # mean
      assert_text "144"       # sum
    end
    screenshot_full_page("61-std-dev-population-result")
  end

  test "switching to sample mode reports the (n-1) standard deviation" do
    visit "/calculators/standard_deviation"
    fill_in "Values", with: "10, 12, 23, 23, 16, 23, 21, 16"
    choose "Sample", allow_label_click: true
    click_button "Calculate"
    within "#result" do
      assert_text "5.237229"   # sample SD
      assert_text "Sample standard deviation"
      assert_text "27.428571"  # sample variance
    end
    screenshot_full_page("62-std-dev-sample-result")
  end

  # Large (6+ digit, unit-less) statistics must NEVER clip at the card's right edge
  # (DESIGN.md §4: "stats must NEVER clip" — the hard floor), and the `--wide` track must
  # keep a realistic 7-digit figure on a SINGLE line (single-line is what `--wide` buys for
  # a high-magnitude value). A text assertion can't see a clip — the value is in the DOM but
  # truncated under the `.stat-card`'s overflow-hidden shell — so we measure the laid-out
  # geometry. Statistical outputs are unbounded, so this is the worst case the frontend agent
  # is required to exercise.
  #
  # Inputs `1000000, 1003000` give mean 1,001,500, sum 2,003,000, SD 1,500 and variance
  # 2,250,000 — every displayed statistic is a 6–7 digit number, the realistic high-magnitude
  # case the `--wide` track is sized for, so all hold on one line. (Variance is the SQUARE of
  # the spread, so a far-apart pair drives it to 10+ digits where DESIGN.md's never-clip floor
  # is wrapping, not single-line; this case pins the single-line guarantee at the 7-digit
  # scale that matches MMR's `6,419,754` worst case.)
  test "large 6+ digit figures fill the stat grid without clipping or mid-number wrap" do
    visit "/calculators/standard_deviation"
    fill_in "Values", with: "1000000, 1003000"
    choose "Population", allow_label_click: true
    click_button "Calculate"
    within "#result" do
      assert_text "2,003,000"  # sum, delimited in full
      assert_text "1,001,500"  # mean
      assert_text "2,250,000"  # variance
      assert_text "1,500"      # standard deviation
    end
    # No-clip is the hard rule, asserted on EVERY value (hero + every card).
    assert_no_value_clip("#result dl.stat-grid--wide .stat-card dd")
    # The `--wide` single-line guarantee for a realistic 7-digit figure.
    assert_no_mid_value_wrap("#result dl.stat-grid--wide .stat-card dd.tabular-nums")
    screenshot_full_page("64-std-dev-large-values")
  end

  test "a non-numeric token shows the label-based error fragment" do
    visit "/calculators/standard_deviation"
    fill_in "Values", with: "1, two, 3"
    choose "Population", allow_label_click: true
    click_button "Calculate"
    within "#result" do
      # The eyebrow is uppercased by CSS, so the rendered text is "CHECK YOUR INPUT".
      assert_text "CHECK YOUR INPUT"
      assert_selector "[role=alert] li", text: "Values must be a list of numbers"
    end
    screenshot_full_page("63-std-dev-error")
  end
end
