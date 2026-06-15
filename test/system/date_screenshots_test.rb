require "application_system_test_case"

# Drives the real browser through the Date page's key states and saves a full-page
# screenshot of each (issue #195). Doubles as a Turbo regression check (the form posts over
# Turbo and the #result fragment updates in place), a Stimulus mode-gating check (selecting
# a mode reveals its fields), and a visual artifact reviewed against docs/DESIGN.md (CI
# uploads the PNGs). No chart on this page, so no canvas-paint assertion applies.
class DateScreenshotsTest < ApplicationSystemTestCase
  test "empty state before any submission" do
    visit "/calculators/date"
    assert_selector "h1", text: "Date Calculator"
    assert_text "your answer appears here"
    # The mode picker defaults to difference, so the two date fields are visible.
    assert_field "Start date"
    assert_field "End date"
    screenshot_full_page("60-date-default")
  end

  test "computes the difference between two dates and renders the hero result over Turbo" do
    visit "/calculators/date"
    # Headless Chrome's native <input type="date"> takes keystrokes in en-US MM/DD/YYYY order.
    fill_in "Start date", with: "01/15/2023"
    fill_in "End date", with: "03/20/2025"
    click_button "Calculate"
    within "#result" do
      assert_text "2 years · 2 months · 5 days"
      assert_text "795"
      assert_text "113 weeks and 4 days"
    end
    # The wide-track stat grid holds the day counts on one line and never clips (DESIGN §4).
    assert_no_mid_value_wrap("#result dl.stat-grid--wide .stat-card dd")
    assert_no_value_clip("#result dl.stat-grid--wide .stat-card dd")
    screenshot_full_page("61-date-difference-result")
  end

  test "a multi-century span renders a 6-digit day count without clipping" do
    visit "/calculators/date"
    fill_in "Start date", with: "01/01/1753"
    fill_in "End date", with: "01/01/2025"
    click_button "Calculate"
    within "#result" do
      assert_text "99,346" # six digits, delimited, in full
    end
    # The worst-case figure must hold on one line on the wide track and never clip.
    assert_no_mid_value_wrap("#result dl.stat-grid--wide .stat-card dd")
    assert_no_value_clip("#result dl.stat-grid--wide .stat-card dd")
    screenshot_full_page("62-date-difference-large")
  end

  test "switching to add/subtract reveals its fields and computes a resulting date" do
    visit "/calculators/date"
    # Selecting the second mode-option reveals the add_subtract block (Stimulus mode-gating).
    # The radio is visually-hidden (sr-only) under its styled label, so click the label.
    choose "Add to or subtract from a date", allow_label_click: true
    assert_selector "fieldset legend", text: "Operation"
    fill_in "inputs_start_date_add", with: "01/01/2024"
    fill_in "inputs_days", with: "30"
    click_button "Calculate"
    within "#result" do
      # The eyebrow is uppercased by CSS, so the rendered text is "RESULTING DATE".
      assert_text "RESULTING DATE"
      assert_text "2024-01-31"
      assert_text "Wednesday, January 31, 2024"
    end
    screenshot_full_page("63-date-add-subtract-result")
  end

  test "invalid input shows the error fragment" do
    visit "/calculators/date"
    # Difference with a blank end date → server 422 → error fragment in #result.
    fill_in "Start date", with: "01/01/2024"
    click_button "Calculate"
    within "#result" do
      # The eyebrow is uppercased by CSS, so the rendered text is "CHECK YOUR INPUT".
      assert_text "CHECK YOUR INPUT"
      assert_selector "[role=alert] li", text: "End date can't be blank"
    end
    screenshot_full_page("64-date-error")
  end
end
