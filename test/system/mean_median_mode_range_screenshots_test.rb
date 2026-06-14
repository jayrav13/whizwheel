require "application_system_test_case"

# Drives the real browser through the Mean/Median/Mode/Range page's key states and saves a
# full-page screenshot of each (issue #80). Doubles as a Turbo regression check (the form
# posts over Turbo and the #result fragment updates in place — there is no Stimulus here,
# this is the plainest calculator: one list field, one submit) and a visual artifact
# reviewed against docs/DESIGN.md (CI uploads the PNGs). The variable-length list input and
# the array-valued `mode` (bimodal / "No mode") are the things this calculator stresses.
class MeanMedianModeRangeScreenshotsTest < ApplicationSystemTestCase
  test "default empty state with the list input" do
    visit "/calculators/mean_median_mode_range"
    assert_selector "h1", text: "Mean, Median, Mode, Range Calculator"
    assert_field "Numbers"
    assert_text "your answer appears here"
    screenshot_full_page("30-mmr-default")
  end

  test "a bimodal list renders all eight statistics and both modes over Turbo" do
    visit "/calculators/mean_median_mode_range"
    fill_in "Numbers", with: "10, 2, 38, 23, 38, 23, 21"
    click_button "Calculate"
    within "#result" do
      assert_text "22.143"   # mean
      assert_text "23 and 38" # bimodal mode
      assert_text "36"        # range
      assert_text "155"       # sum
    end
    screenshot_full_page("31-mmr-bimodal-result")
  end

  test "an all-unique list renders 'No mode'" do
    visit "/calculators/mean_median_mode_range"
    fill_in "Numbers", with: "1, 2, 3, 4, 5"
    click_button "Calculate"
    within "#result" do
      assert_text "No mode"
      assert_text "3" # mean / median
    end
    screenshot_full_page("32-mmr-no-mode-result")
  end

  test "large 6+ digit figures fill the auto-fit stat grid without clipping" do
    visit "/calculators/mean_median_mode_range"
    fill_in "Numbers", with: "1234567, 7654321"
    click_button "Calculate"
    within "#result" do
      assert_text "8,888,888"  # sum, delimited in full
      assert_text "6,419,754"  # range, delimited in full
      assert_text "7,654,321"  # largest
      assert_text "1,234,567"  # smallest
    end
    screenshot_full_page("34-mmr-large-values")
  end

  test "a non-numeric token shows the label-based error fragment" do
    visit "/calculators/mean_median_mode_range"
    fill_in "Numbers", with: "1, 2, banana"
    click_button "Calculate"
    within "#result" do
      # The eyebrow is uppercased by CSS, so the rendered text is "CHECK YOUR INPUT".
      assert_text "CHECK YOUR INPUT"
      assert_selector "[role=alert] li", text: "Numbers contains a value that is not a number: banana"
    end
    screenshot_full_page("33-mmr-error")
  end
end
