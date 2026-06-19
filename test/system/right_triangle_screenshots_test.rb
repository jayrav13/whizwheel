require "application_system_test_case"

# Drives the real browser through the Right Triangle page's key states and saves a
# full-page screenshot of each (issue #193). Doubles as a Turbo/Stimulus regression check
# (the form submits over Turbo and the #result fragment updates in place; the Stimulus
# controller shows only the chosen mode's side fields) and a visual artifact reviewed
# against docs/DESIGN.md (CI uploads the PNGs). The result renders an SVG triangle figure —
# its presence is asserted here.
class RightTriangleScreenshotsTest < ApplicationSystemTestCase
  test "default mode with empty result" do
    visit "/calculators/right_triangle"
    assert_selector "h1", text: "Right Triangle Calculator"
    # legs is the default mode: Leg a + Leg b visible, Hypotenuse hidden.
    assert_field "Leg a"
    assert_field "Leg b"
    assert_no_field "Hypotenuse (c)", visible: true
    assert_text "your answer appears here"
    screenshot_full_page("40-right-triangle-default")
  end

  test "legs mode solves the hypotenuse and draws the labelled triangle figure" do
    visit "/calculators/right_triangle"
    fill_in "Leg a", with: "3"
    fill_in "Leg b", with: "4"
    click_button "Calculate"
    within "#result" do
      assert_text "Solved triangle".upcase  # eyebrow uppercased by CSS
      assert_text "5"          # solved hypotenuse
      assert_text "36.869898"  # alpha
      assert_text "53.130102"  # beta
      assert_text "2.4"        # altitude
      # The SVG figure is present and labels the sides.
      assert_selector "figure svg[role=img]"
      assert_selector "figure svg polygon"
    end
    # The wide-track stat grid must keep the long 6-decimal angle values on ONE line
    # (e.g. "53.130102°" wraps mid-number on the default 9.5rem track) and never clip
    # (DESIGN.md §4 "Stat grid").
    assert_no_mid_value_wrap("#result dl.stat-grid--wide .stat-card dd span:first-child")
    assert_no_value_clip("#result dl.stat-grid .stat-card dd span")
    screenshot_full_page("41-right-triangle-legs")
  end

  test "leg_hyp mode reveals the hypotenuse field and solves the other leg" do
    visit "/calculators/right_triangle"
    choose "Leg & hypotenuse (a, c)", allow_label_click: true
    # Stimulus now shows Leg a + Hypotenuse, hides Leg b.
    assert_field "Leg a"
    assert_field "Hypotenuse (c)"
    assert_no_field "Leg b", visible: true
    fill_in "Leg a", with: "6"
    fill_in "Hypotenuse (c)", with: "10"
    click_button "Calculate"
    within "#result" do
      assert_text "8"   # solved leg b
      assert_text "24"  # area
      assert_text "4.8" # altitude
      assert_selector "figure svg polygon"
    end
    screenshot_full_page("42-right-triangle-leg-hyp")
  end

  test "large side values render in full without clipping" do
    # Worst-case clip check (frontend agent: "test the worst case"): big legs drive the
    # hypotenuse and perimeter into large delimited figures — they must render whole.
    visit "/calculators/right_triangle"
    fill_in "Leg a", with: "300000"
    fill_in "Leg b", with: "400000"
    click_button "Calculate"
    within "#result" do
      assert_text "500,000"    # solved hypotenuse
      assert_text "1,200,000"  # perimeter
    end
    assert_no_value_clip("#result dl.stat-grid .stat-card dd span")
    # The SVG figure's leg-`a` label ("a = 300,000") must stay INSIDE the figure — anchored
    # `start` just right of the vertical leg, it grows into the triangle interior, never off
    # the left margin (the QA #272 clip propagated from Pythagorean to this figure).
    assert_svg_labels_within_bounds("#result figure svg[role=img]", "text")
    screenshot_full_page("44-right-triangle-large-values")
  end

  test "tall-thin near-degenerate triangle keeps every figure label inside the figure" do
    # Issue #215, the remaining geometry beyond #288's large-VALUE case: a tall-thin triangle
    # (a huge leg a, a tiny leg b) collapses the bottom vertex hard against the figure's left
    # origin, so the `end`-anchored α angle label — which grows LEFTWARD from that vertex —
    # would spill off the figure's left margin without the helper's clamp. We solve leg b from
    # a long leg a and a hypotenuse a hair larger, so b stays tiny: a = 300,000, c = 300,001
    # → b ≈ 774, a ~387:1 sliver. Every SVG label (sides AND both clamped angle labels) must
    # render fully within the figure's horizontal bounds — the worst case #288's check missed.
    visit "/calculators/right_triangle"
    choose "Leg & hypotenuse (a, c)", allow_label_click: true
    fill_in "Leg a", with: "300000"
    fill_in "Hypotenuse (c)", with: "300001"
    click_button "Calculate"
    within "#result" do
      assert_text "Solved triangle".upcase
      assert_selector "figure svg[role=img]"
      assert_selector "figure svg polygon"
      # The α/β angle labels are present in the degenerate figure (the clamp keeps them on-screen).
      assert_selector "figure svg text", text: "α"
      assert_selector "figure svg text", text: "β"
    end
    # No stat-card value clips even on the lopsided geometry.
    assert_no_value_clip("#result dl.stat-grid .stat-card dd span")
    # The pre-existing check: every SVG label — the three side labels AND both clamped angle
    # labels — stays inside the figure's left/right edges, the tall-thin worst case (#215).
    assert_svg_labels_within_bounds("#result figure svg[role=img]", "text")
    screenshot_full_page("45-right-triangle-tall-thin")
  end

  test "invalid input shows the error fragment" do
    visit "/calculators/right_triangle"
    # Submit legs with no numbers → server 422 → error fragment in #result.
    click_button "Calculate"
    within "#result" do
      assert_text "CHECK YOUR INPUT"  # eyebrow uppercased by CSS
      assert_selector "[role=alert] li", text: "Leg a can't be blank"
      assert_selector "[role=alert] li", text: "Leg b can't be blank"
    end
    screenshot_full_page("43-right-triangle-error")
  end
end
