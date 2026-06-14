require "application_system_test_case"

# Drives the real browser through the Tip page's key states and saves a full-page
# screenshot of each (issue #76). Doubles as a Turbo/Stimulus regression check (the form
# posts over Turbo and the #result fragment updates in place; the tip_controller wires the
# quick-pick chips) and a visual artifact reviewed against docs/DESIGN.md (CI uploads the
# PNGs).
class TipScreenshotsTest < ApplicationSystemTestCase
  test "default page with empty result" do
    visit "/calculators/tip"
    assert_selector "h1", text: "Tip Calculator"
    assert_field "Bill amount"
    assert_field "Tip"
    assert_field "People"
    assert_text "your answer appears here"
    screenshot_full_page("30-tip-default")
  end

  test "a quick-pick chip fills the tip percentage and computes a split result over Turbo" do
    visit "/calculators/tip"
    fill_in "Bill amount", with: "50"
    click_button "20%" # the quick-pick chip writes 20 into the percent field
    assert_field "Tip", with: "20"
    fill_in "People", with: "2"
    click_button "Calculate"
    # Turbo replaced #result in place — the hero total + per-person split appear with no reload.
    within "#result" do
      # The eyebrow labels are uppercased by CSS, so the rendered text is upper-case.
      assert_text "TOTAL TO PAY"
      assert_text "$60.00"
      assert_text "SPLIT 2 WAYS"
      assert_text "$30.00"
    end
    screenshot_full_page("31-tip-split-result")
  end

  test "a single-person bill shows the total without a per-person split" do
    visit "/calculators/tip"
    fill_in "Bill amount", with: "128.57"
    fill_in "Tip", with: "18"
    # People defaults to 1.
    click_button "Calculate"
    within "#result" do
      assert_text "$151.71"
      assert_text "$23.14"
      assert_no_text "Split"
    end
    screenshot_full_page("32-tip-single-result")
  end

  test "invalid input shows the error fragment" do
    visit "/calculators/tip"
    # Submit with no bill and no tip → server 422 → error fragment in #result.
    click_button "Calculate"
    within "#result" do
      # The eyebrow is uppercased by CSS, so the rendered text is "CHECK YOUR INPUT".
      assert_text "CHECK YOUR INPUT"
      assert_selector "[role=alert] li", text: "Bill amount can't be blank"
    end
    screenshot_full_page("33-tip-error")
  end
end
