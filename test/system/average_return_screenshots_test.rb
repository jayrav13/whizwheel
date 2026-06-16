require "application_system_test_case"

# Drives the real browser through the Average Return page's key states and saves a full-page
# screenshot of each (issue #257). The headline interaction here is the DYNAMIC ADD/REMOVE
# list (the `return_list` Stimulus controller): this test exercises adding rows, filling them,
# removing one, watching the live period-count chip, and computing both averages over Turbo —
# the things this calculator stresses beyond a plain form. Doubles as a visual artifact
# reviewed against docs/DESIGN.md (CI uploads the PNGs).
class AverageReturnScreenshotsTest < ApplicationSystemTestCase
  test "default empty state with the starter return rows" do
    visit "/calculators/average_return"
    assert_selector "h1", text: "Average Return Calculator"
    assert_text "Period returns"
    assert_text "your answer appears here"
    # The starter rows render as a labelled list (no value yet).
    assert_selector "[data-return-list-target='row']", minimum: 2
    assert_text "3 periods"
    screenshot_full_page("80-average-return-default")
  end

  test "adding and removing rows updates the live period count" do
    visit "/calculators/average_return"
    initial = all("[data-return-list-target='row']").size
    click_button "Add return"
    click_button "Add return"
    assert_selector "[data-return-list-target='row']", count: initial + 2
    assert_text "#{initial + 2} periods"
    # Remove one row — the count steps back down.
    first("button[data-action='return-list#remove']:not([hidden])").click
    assert_selector "[data-return-list-target='row']", count: initial + 1
    assert_text "#{initial + 1} periods"
    screenshot_full_page("81-average-return-add-remove")
  end

  test "computing both averages from a filled list over Turbo" do
    visit "/calculators/average_return"
    # The spec's worked anchor [10, 20, −5, 15] needs a 4th row beyond the 3 starters.
    click_button "Add return"
    inputs = all("input[name='inputs[returns][]']")
    %w[10 20 -5 15].each_with_index { |v, i| inputs[i].set(v) }
    click_button "Calculate"
    within "#result" do
      assert_text "9.5844"   # geometric average
      assert_text "10.0000"  # arithmetic average
      assert_text "Geometric average"
      assert_text "Arithmetic average"
      # The raw returns echoed back in the monospace code block.
      assert_text "[10, 20, -5, 15]"
    end
    screenshot_full_page("82-average-return-result")
  end

  test "a net-loss list renders signed negative averages" do
    visit "/calculators/average_return"
    inputs = all("input[name='inputs[returns][]']")
    inputs[0].set("10")
    inputs[1].set("-10")
    inputs[2].set("") # leave the third starter row blank → dropped by the server
    click_button "Calculate"
    within "#result" do
      assert_text "0.0000"    # arithmetic
      assert_text "-0.5013"   # geometric, signed negative
    end
    screenshot_full_page("83-average-return-negative")
  end

  test "a large average fills the stat grid without clipping" do
    visit "/calculators/average_return"
    inputs = all("input[name='inputs[returns][]']")
    inputs[0].set("2000000")
    inputs[1].set("2000000")
    inputs[2].set("")
    click_button "Calculate"
    within "#result" do
      assert_text "2,000,000.0000" # arithmetic, delimited + 4dp, in full
    end
    # The big tabular-nums average must NOT clip at the card's right edge (DESIGN.md §4: stats
    # must NEVER clip). A text assertion can't see a clip — the value is in the DOM but
    # truncated under the `.stat-card`'s overflow-hidden shell — so measure the laid-out
    # geometry: the value's content must fit within (or wrap inside) its visible box.
    assert_no_value_clip("#result dl.stat-grid .stat-card dd")
    screenshot_full_page("84-average-return-large")
  end

  test "a return below −100% shows the label-based error fragment" do
    visit "/calculators/average_return"
    inputs = all("input[name='inputs[returns][]']")
    inputs[0].set("10")
    inputs[1].set("-150")
    inputs[2].set("")
    click_button "Calculate"
    within "#result" do
      # The eyebrow is uppercased by CSS, so the rendered text is "CHECK YOUR INPUT".
      assert_text "CHECK YOUR INPUT"
      assert_selector "[role=alert] li", text: /Returns each return must be at least −100%/
    end
    screenshot_full_page("85-average-return-error")
  end
end
