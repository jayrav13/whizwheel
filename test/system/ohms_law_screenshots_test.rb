require "application_system_test_case"

# Drives the real browser through the Ohm's Law page's key states and saves a
# full-page screenshot of each (issue #55). Doubles as a Turbo/Stimulus regression
# check (the form submits over Turbo and the #result fragment updates in place; the
# Stimulus controller shows only the chosen mode's two inputs) and a visual artifact
# reviewed against docs/DESIGN.md (CI uploads the PNGs).
class OhmsLawScreenshotsTest < ApplicationSystemTestCase
  test "default mode with empty result" do
    visit "/calculators/ohms_law"
    assert_selector "h1", text: "Ohm's Law Calculator"
    # vi is the default mode: Voltage + Current visible, Resistance + Power hidden.
    assert_field "Voltage (V)"
    assert_field "Current (I)"
    assert_no_field "Resistance (R)", visible: true
    assert_no_field "Power (P)", visible: true
    assert_text "your answer appears here"
    screenshot_full_page("20-ohms-law-default")
  end

  test "computes vi mode and renders the solved V/I/R/P set over Turbo" do
    visit "/calculators/ohms_law"
    fill_in "Voltage (V)", with: "12"
    fill_in "Current (I)", with: "2"
    click_button "Calculate"
    # Turbo replaced #result in place — all four quantities appear without a reload.
    within "#result" do
      assert_text "12"  # given voltage
      assert_text "6"   # solved resistance
      assert_text "24"  # solved power
      # Tags are uppercased by CSS, so the rendered text reads "SOLVED" / "GIVEN".
      assert_text "SOLVED"
      assert_text "GIVEN"
    end
    screenshot_full_page("21-ohms-law-result")
  end

  test "rp mode reveals resistance + power and solves the square-root branch" do
    visit "/calculators/ohms_law"
    choose "Resistance & Power", allow_label_click: true
    # Stimulus now shows Resistance + Power, hides Voltage + Current.
    assert_field "Resistance (R)"
    assert_field "Power (P)"
    assert_no_field "Voltage (V)", visible: true
    assert_no_field "Current (I)", visible: true
    fill_in "Resistance (R)", with: "4"
    fill_in "Power (P)", with: "36"
    click_button "Calculate"
    within "#result" do
      assert_text "12"  # solved voltage
      assert_text "3"   # solved current = √(36/4)
    end
    screenshot_full_page("22-ohms-law-rp")
  end

  test "large 6+ digit solved values fill the stat grid without clipping" do
    # The responsive auto-fit stat grid (DESIGN.md §4) must hold large figures without
    # truncation — drive a high-power circuit so R and P become 6+ digit numbers and
    # screenshot it for visual review.
    visit "/calculators/ohms_law"
    fill_in "Voltage (V)", with: "999000"
    fill_in "Current (I)", with: "999"
    click_button "Calculate"
    within "#result" do
      assert_text "998,001,000"  # solved power — a 9-digit figure, rendered in full
      assert_text "999,000"      # given voltage echoes back at full width
    end
    screenshot_full_page("24-ohms-law-large-values")
  end

  test "invalid input shows the error fragment" do
    visit "/calculators/ohms_law"
    # Submit vi with no numbers → server 422 → error fragment in #result.
    click_button "Calculate"
    within "#result" do
      # The eyebrow is uppercased by CSS, so the rendered text is "CHECK YOUR INPUT".
      assert_text "CHECK YOUR INPUT"
      # Errors read against the visible labels, not the raw attribute keys.
      assert_selector "[role=alert] li", text: "Voltage (V) can't be blank"
      assert_selector "[role=alert] li", text: "Current (I) can't be blank"
    end
    screenshot_full_page("23-ohms-law-error")
  end
end
