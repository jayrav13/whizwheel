require "application_system_test_case"

# Drives the real browser through the Percentage page's key states and saves a full-page
# screenshot of each (issue #31), regenerated for iteration-0005. Doubles as a Turbo/
# Stimulus regression check (the form submits over Turbo and the #result fragment updates
# in place; the Stimulus controller hides irrelevant fields per mode) and as the visual
# artifact reviewed against docs/DESIGN.md (CI uploads the PNGs).
class PercentageScreenshotsTest < ApplicationSystemTestCase
  test "default mode with empty result" do
    visit "/calculators/percentage"
    assert_selector "h1", text: "Percentage Calculator"
    # The main mode picker is the selectable option list: five full-width rows, each with
    # a bold mode label + a one-line helper naming what it computes.
    assert_selector "label.mode-option", count: 5
    assert_selector "label.mode-option", text: "Percent of a number"
    assert_selector "label.mode-option", text: "What is P% of a number"
    # percent_of is the default mode: V1 + Percent visible, V2 hidden by Stimulus.
    assert_field "Value (V1)"
    assert_field "Percent (P)"
    assert_no_field "Value (V2)", visible: true
    assert_text "your answer appears here"
    screenshot_full_page("10-percentage-default")
  end

  test "computes percent_of and renders the hero result over Turbo" do
    visit "/calculators/percentage"
    fill_in "Value (V1)", with: "50"
    fill_in "Percent (P)", with: "20"
    click_button "Calculate"
    # Turbo replaced #result in place — the hero number appears without a reload.
    within "#result" do
      assert_text "10"
      assert_text "20% of 50"
    end
    screenshot_full_page("11-percentage-result")
  end

  test "change mode reveals the increase/decrease toggle" do
    visit "/calculators/percentage"
    choose "Increase / decrease", allow_label_click: true
    # Stimulus now shows V1 + Percent + Direction, hides V2.
    assert_field "Value (V1)"
    assert_field "Percent (P)"
    assert_no_field "Value (V2)", visible: true
    assert_selector "label", text: "Increase"
    assert_selector "label", text: "Decrease"
    fill_in "Value (V1)", with: "500"
    fill_in "Percent (P)", with: "10"
    choose "Decrease", allow_label_click: true
    click_button "Calculate"
    within "#result" do
      assert_text "450"
    end
    screenshot_full_page("12-percentage-change")
  end

  test "invalid input shows the error fragment" do
    visit "/calculators/percentage"
    # Submit percent_of with no numbers → server 422 → error fragment in #result.
    click_button "Calculate"
    within "#result" do
      # The eyebrow is uppercased by CSS, so the rendered text is "CHECK YOUR INPUT".
      assert_text "CHECK YOUR INPUT"
      # Errors read against the visible labels, not the raw attribute keys.
      assert_selector "[role=alert] li", text: "Value (V1) can't be blank"
      assert_selector "[role=alert] li", text: "Percent (P) can't be blank"
    end
    screenshot_full_page("13-percentage-error")
  end
end
