require "application_system_test_case"

# Drives the real browser through the Income Tax page's key states and saves a full-page
# screenshot of each (issue #260). Doubles as a Turbo/Stimulus regression check (the form
# posts over Turbo and the #result fragment updates in place; the Stimulus controller reveals
# only the active mode's field block and lifts the active option row) and a visual artifact
# reviewed against docs/DESIGN.md (CI uploads the PNGs).
class IncomeTaxScreenshotsTest < ApplicationSystemTestCase
  test "default state with empty result" do
    visit "/calculators/income_tax"
    assert_selector "h1", text: "Income Tax Calculator"
    # The income picker is the selectable option list (Taxable income default | Gross income).
    assert_selector "label.mode-option", text: "Taxable income"
    assert_selector "label.mode-option", text: "Gross income"
    # Taxable mode is default → the taxable-income field is visible; the gross fields are
    # hidden (the Stimulus controller reveals only the active mode's block). Assert visibility
    # rather than presence — the no-JS baseline keeps both blocks in the DOM.
    assert_field "Taxable income"
    assert_no_selector "label[for=inputs_gross_income]", visible: true
    assert_text "your answer appears here"
    screenshot_full_page("income-tax-default")
  end

  test "computes a direct taxable income and renders the hero result over Turbo" do
    visit "/calculators/income_tax"
    fill_in "Taxable income", with: "250000"
    click_button "Calculate tax"
    # Turbo replaced #result in place — the hero total, stat grid + bracket table appear.
    within "#result" do
      # The eyebrow is uppercased by CSS, so the rendered text is "TOTAL FEDERAL INCOME TAX".
      assert_text "TOTAL FEDERAL INCOME TAX"
      assert_text "57,063.00"
      assert_text "192,937.00"  # after-tax income
      assert_text "22.8252%"    # effective rate
      assert_text "32%"         # marginal rate
      # The per-bracket breakdown table — the worked-anchor 22% bracket.
      assert_text "12,072.50"
    end
    # The bracket RANGE cell (e.g. "$103,350 – $197,300") must render single-line — it must
    # not wrap mid-range across two lines (the iteration-0007 harvest fix, DESIGN.md §4 "Data
    # table": numeric/range cells nowrap inside `.data-table`). Measure the laid-out range
    # `<code>` cells: a wrapped one would be ~2 line-heights tall.
    assert_no_mid_value_wrap("#result table.data-table tbody td code.tabular-nums")
    screenshot_full_page("income-tax-result")
  end

  test "gross income mode reveals deductions and derives the taxable income" do
    visit "/calculators/income_tax"
    choose "Gross income & deductions", allow_label_click: true
    # Switching mode reveals the gross + deductions fields and hides the taxable field.
    assert_field "Gross income"
    assert_field "Deductions"
    assert_no_selector "label[for=inputs_taxable_income]", visible: true
    fill_in "Gross income", with: "60000"
    fill_in "Deductions", with: "14600"
    click_button "Calculate tax"
    within "#result" do
      assert_text "45,400.00"  # derived taxable income
      assert_text "5,209.50"   # total tax
    end
    screenshot_full_page("income-tax-gross")
  end

  test "a seven-figure income lays out in the stat grid without clipping or mid-value wrap" do
    visit "/calculators/income_tax"
    fill_in "Taxable income", with: "1000000"
    click_button "Calculate tax"
    within "#result" do
      # 1,000,000 taxable → 327,020.25 tax, 672,979.75 after-tax.
      assert_text "327,020.25"
      assert_text "672,979.75"
      assert_text "1,000,000.00"
    end
    # The --wide stat grid must keep each money figure on ONE line and never clip it
    # (DESIGN.md §4 "Stat grid" — high-magnitude money). Measure the laid-out value cells.
    assert_no_mid_value_wrap("#result dl.stat-grid--wide .stat-card dd")
    assert_no_value_clip("#result dl.stat-grid--wide .stat-card dd")
    screenshot_full_page("income-tax-large")
  end

  test "zero taxable income shows the no-tax breakdown note" do
    visit "/calculators/income_tax"
    fill_in "Taxable income", with: "0"
    click_button "Calculate tax"
    within "#result" do
      assert_text "0.00"
      assert_text "no federal income tax is owed"
    end
    screenshot_full_page("income-tax-zero")
  end

  test "invalid input shows the error fragment" do
    visit "/calculators/income_tax"
    # Submit with no income → server 422 → error fragment in #result.
    click_button "Calculate tax"
    within "#result" do
      # The eyebrow is uppercased by CSS, so the rendered text is "CHECK YOUR INPUT".
      assert_text "CHECK YOUR INPUT"
      assert_selector "[role=alert] li", text: "Taxable income can't be blank"
    end
    screenshot_full_page("income-tax-error")
  end
end
