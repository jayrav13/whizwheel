require "application_system_test_case"

# Drives the real browser through the Age page's key states and saves a full-page
# screenshot of each (issue #82). Doubles as a Turbo regression check (the form posts
# over Turbo and the #result fragment updates in place) and a visual artifact reviewed
# against docs/DESIGN.md (CI uploads the PNGs). The age_controller wires the optional
# end-date's "Today" quick-fill button (DESIGN.md §4) as pure enhancement; the two native
# date fields and the server's default-to-today are the rest of the interaction.
class AgeScreenshotsTest < ApplicationSystemTestCase
  test "empty state before any submission" do
    visit "/calculators/age"
    assert_selector "h1", text: "Age Calculator"
    assert_text "your answer appears here"
    screenshot_full_page("30-age-default")
  end

  test "computes an age from two dates and renders the hero result over Turbo" do
    visit "/calculators/age"
    # Headless Chrome's native <input type="date"> takes keystrokes in the en-US
    # MM/DD/YYYY order, not the ISO value the field ultimately submits.
    fill_in "Date of birth", with: "06/15/1990"
    fill_in "Age at the date of", with: "06/14/2024"
    click_button "Calculate age"
    # Turbo replaced #result in place — the breakdown + totals appear without a reload.
    within "#result" do
      assert_text "33"
      assert_text "11 months · 30 days"
      assert_text "12,418"
    end
    screenshot_full_page("31-age-result")
  end

  test "the Today button fills the optional end date (progressive enhancement)" do
    visit "/calculators/age"
    # The end date starts blank — DESIGN.md §4: never auto-prefilled.
    assert_field "Age at the date of", with: ""
    # Tapping "Today" fills the current date into the optional end-date field.
    click_button "Today"
    filled = find_field("Age at the date of").value
    # The button's value comes from the BROWSER's clock (age_controller's new Date());
    # the expected is read here from Ruby's Date.current. Those two reads happen at
    # different instants, so across the midnight boundary they can land on adjacent
    # calendar days (observed: filled 2026-06-15 vs expected 2026-06-14). Asserting an
    # exact day is therefore a date-boundary flake — instead require a valid ISO
    # YYYY-MM-DD whose day is within the ±1-day window around Date.current at assertion
    # time. This is deterministic on either side of midnight while still proving the
    # button fills *today's* date (not blank, not a hardcoded constant).
    assert_match(/\A\d{4}-\d{2}-\d{2}\z/, filled,
      "Today should fill a valid ISO date, got #{filled.inspect}")
    today = Date.current
    acceptable = [ today.prev_day, today, today.next_day ].map { |d| d.strftime("%Y-%m-%d") }
    assert_includes acceptable, filled,
      "Today should fill today's date (±1 day for the midnight boundary), got #{filled.inspect}"
    screenshot_full_page("33-age-today-filled")
  end

  test "a large multi-decade span renders 6-digit totals without clipping" do
    visit "/calculators/age"
    # A 35-year exact-anniversary span → total_hours = 306,792 (six digits). The
    # responsive auto-fit stat grid (DESIGN.md §4) must show it in full; this shot is the
    # visual guard against the Total-hours crowding/cutoff this regen fixes.
    fill_in "Date of birth", with: "01/01/1989"
    fill_in "Age at the date of", with: "01/01/2024"
    click_button "Calculate age"
    within "#result" do
      assert_text "35"
      assert_text "306,792"
    end
    screenshot_full_page("34-age-large-totals")
  end

  test "invalid input shows the error fragment" do
    visit "/calculators/age"
    # Birth after end → server 422 → error fragment in #result. (en-US MM/DD/YYYY
    # keystroke order for the native date control.)
    fill_in "Date of birth", with: "06/15/2024"
    fill_in "Age at the date of", with: "06/14/2024"
    click_button "Calculate age"
    within "#result" do
      # The eyebrow is uppercased by CSS, so the rendered text is "CHECK YOUR INPUT".
      assert_text "CHECK YOUR INPUT"
      assert_selector "[role=alert] li", text: "Date of birth must be on or before the end date"
    end
    screenshot_full_page("32-age-error")
  end
end
