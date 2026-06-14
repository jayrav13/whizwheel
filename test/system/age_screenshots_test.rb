require "application_system_test_case"

# Drives the real browser through the Age page's key states and saves a full-page
# screenshot of each (issue #82). Doubles as a Turbo regression check (the form posts
# over Turbo and the #result fragment updates in place) and a visual artifact reviewed
# against docs/DESIGN.md (CI uploads the PNGs). Age has no Stimulus controller — the two
# native date fields and the server's default-to-today are the whole interaction.
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
