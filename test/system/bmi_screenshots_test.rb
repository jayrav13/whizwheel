require "application_system_test_case"

# Drives the real browser through the BMI page's key states and saves a full-page
# screenshot of each (issue #53). Doubles as a Turbo/Stimulus regression check (the form
# posts over Turbo and the #result fragment updates in place; the bmi_controller swaps
# the height affordance and weight unit by unit system) and a visual artifact reviewed
# against docs/DESIGN.md (CI uploads the PNGs).
class BmiScreenshotsTest < ApplicationSystemTestCase
  test "default US mode with empty result" do
    visit "/calculators/bmi"
    assert_selector "h1", text: "BMI Calculator"
    # US is the default: with JS the ft+in helpers show, the raw total-inches field hides.
    assert_field "Feet"
    assert_field "Inches"
    assert_no_field "Total height in inches", visible: true
    assert_text "your answer appears here"
    screenshot_full_page("20-bmi-default")
  end

  test "computes a US BMI from feet + inches and renders the hero result over Turbo" do
    visit "/calculators/bmi"
    fill_in "Weight", with: "160"
    fill_in "Feet", with: "5"
    fill_in "Inches", with: "10" # 5'10" = 70 in
    click_button "Calculate"
    # Turbo replaced #result in place — the BMI + WHO category appear without a reload.
    within "#result" do
      assert_text "23.0"
      assert_text "Normal"
    end
    screenshot_full_page("21-bmi-us-result")
  end

  test "metric mode swaps to a centimetres height field and the kg weight unit" do
    visit "/calculators/bmi"
    choose "Metric units", allow_label_click: true
    # Stimulus now shows the cm height field and hides the US ft+in helpers.
    assert_no_field "Feet", visible: true
    fill_in "Weight", with: "95"
    fill_in "Height", with: "165"
    click_button "Calculate"
    within "#result" do
      assert_text "34.9"
      assert_text "Obese Class I"
    end
    screenshot_full_page("22-bmi-metric-result")
  end

  test "invalid input shows the error fragment" do
    visit "/calculators/bmi"
    choose "Metric units", allow_label_click: true
    # Submit with no numbers → server 422 → error fragment in #result.
    click_button "Calculate"
    within "#result" do
      # The eyebrow is uppercased by CSS, so the rendered text is "CHECK YOUR INPUT".
      assert_text "CHECK YOUR INPUT"
      assert_selector "[role=alert] li", text: "Weight can't be blank"
      assert_selector "[role=alert] li", text: "Height can't be blank"
    end
    screenshot_full_page("23-bmi-error")
  end
end
