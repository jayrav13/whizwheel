require "application_system_test_case"

# Drives the real browser through the Pythagorean Theorem page's key states and saves a
# full-page screenshot of each (spec issue #253). Doubles as a Turbo/Stimulus regression
# check (the form submits over Turbo and the #result fragment updates in place; the Stimulus
# controller shows only the chosen mode's two given side fields) and a visual artifact
# reviewed against docs/DESIGN.md (CI uploads the PNGs). The result renders an SVG triangle
# figure — its presence is asserted here.
class PythagoreanTheoremScreenshotsTest < ApplicationSystemTestCase
  test "default mode with empty result" do
    visit "/calculators/pythagorean_theorem"
    assert_selector "h1", text: "Pythagorean Theorem Calculator"
    # hypotenuse is the default mode: Leg a + Leg b visible, Hypotenuse hidden.
    assert_field "Leg a"
    assert_field "Leg b"
    assert_no_field "Hypotenuse (c)", visible: true
    assert_text "your answer appears here"
    screenshot_full_page("60-pythagorean-default")
  end

  test "hypotenuse mode solves c and draws the labelled triangle figure" do
    visit "/calculators/pythagorean_theorem"
    fill_in "Leg a", with: "3"
    fill_in "Leg b", with: "4"
    click_button "Calculate"
    within "#result" do
      assert_text "Solved hypotenuse c".upcase  # eyebrow uppercased by CSS
      assert_text "5"                # solved hypotenuse
      assert_text "Solved".upcase    # the solved-side state tag (uppercased by CSS)
      assert_text "Given".upcase     # the given-side state tag (uppercased by CSS)
      # The SVG figure is present and labels the sides.
      assert_selector "figure svg[role=img]"
      assert_selector "figure svg polygon"
      # The substituted equation is echoed in monospace.
      assert_selector "code.font-mono"
    end
    # The wide-track stat grid must keep a large hypotenuse on ONE line and never clip
    # (DESIGN.md §4 "Stat grid").
    assert_no_value_clip("#result dl.stat-grid .stat-card dd span")
    screenshot_full_page("61-pythagorean-hypotenuse")
  end

  test "irrational hypotenuse renders the full six-decimal figure" do
    visit "/calculators/pythagorean_theorem"
    fill_in "Leg a", with: "1"
    fill_in "Leg b", with: "1"
    click_button "Calculate"
    within "#result" do
      assert_text "1.414214"  # √2 to six decimals
    end
    screenshot_full_page("64-pythagorean-irrational")
  end

  test "leg mode reveals the hypotenuse field and solves the other leg" do
    visit "/calculators/pythagorean_theorem"
    choose "Solve a leg", allow_label_click: true
    # Stimulus now shows Leg a + Hypotenuse, hides Leg b.
    assert_field "Leg a"
    assert_field "Hypotenuse (c)"
    assert_no_field "Leg b", visible: true
    fill_in "Leg a", with: "5"
    fill_in "Hypotenuse (c)", with: "13"
    click_button "Calculate"
    within "#result" do
      assert_text "Solved leg b".upcase
      assert_text "12"  # solved leg b
      assert_selector "figure svg polygon"
    end
    screenshot_full_page("62-pythagorean-leg")
  end

  test "large side values render in full without clipping" do
    # Worst-case clip check (frontend agent: "test the worst case"): big legs drive the
    # hypotenuse into a large delimited figure — it must render whole.
    visit "/calculators/pythagorean_theorem"
    fill_in "Leg a", with: "300000"
    fill_in "Leg b", with: "400000"
    click_button "Calculate"
    within "#result" do
      assert_text "500,000"  # solved hypotenuse
    end
    assert_no_value_clip("#result dl.stat-grid .stat-card dd span")
    screenshot_full_page("65-pythagorean-large-values")
  end

  test "invalid input shows the error fragment" do
    visit "/calculators/pythagorean_theorem"
    # Submit with no numbers → server 422 → error fragment in #result.
    click_button "Calculate"
    within "#result" do
      assert_text "CHECK YOUR INPUT"  # eyebrow uppercased by CSS
      assert_selector "[role=alert] li", text: "Leg a can't be blank"
      assert_selector "[role=alert] li", text: "Leg b can't be blank"
    end
    screenshot_full_page("63-pythagorean-error")
  end
end
