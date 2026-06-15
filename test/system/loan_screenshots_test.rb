require "application_system_test_case"

# Drives the real browser through the Loan page's key states and saves a full-page
# screenshot of each (issue #185) — a fixed-rate amortizing loan with a solve-for mode
# picker. Doubles as a Turbo/Stimulus regression check (the form posts over Turbo and the
# #result fragment updates in place; the loan_controller reveals only the active mode's
# given fields) and a visual artifact reviewed against docs/DESIGN.md (CI uploads the PNGs).
class LoanScreenshotsTest < ApplicationSystemTestCase
  test "empty result before any submission, with payment mode's given fields shown" do
    visit "/calculators/loan"
    assert_selector "h1", text: "Loan Calculator"
    # Default mode is "payment" → loan amount, rate and term are shown; monthly payment is
    # hidden (it's the figure this mode solves for). The mode-option labels collide with the
    # field labels ("Monthly payment" names both a radio and a field), so assert field
    # visibility on the input id directly rather than by label.
    assert_selector "input#inputs_loan_amount", visible: true
    assert_selector "input#inputs_annual_rate", visible: true
    assert_selector "input#inputs_term_months", visible: true
    assert_no_selector "input#inputs_monthly_payment", visible: true
    assert_text "your answer appears here"
    screenshot_full_page("60-loan-default")
  end

  test "switching to term mode reveals the loan amount + monthly payment, hides term" do
    visit "/calculators/loan"
    # The mode picker is a native radio option list with a visually-hidden (sr-only) radio,
    # so click the label; choosing "Term" re-gates the fields.
    choose "Term", allow_label_click: true
    assert_selector "input#inputs_loan_amount", visible: true
    assert_selector "input#inputs_monthly_payment", visible: true
    assert_selector "input#inputs_annual_rate", visible: true
    assert_no_selector "input#inputs_term_months", visible: true # term is what this mode solves for
    screenshot_full_page("61-loan-term-mode")
  end

  test "computes a monthly payment and renders the hero, stat grid and schedule" do
    visit "/calculators/loan"
    fill_in "Loan amount", with: "25000"
    fill_in "Annual interest rate", with: "5"
    fill_in "Loan term", with: "60"
    click_button "Calculate"
    # Turbo replaced #result in place — the solved-for hero + totals appear without a reload.
    within "#result" do
      assert_text "471.78"      # monthly payment (the hero)
      assert_text "28,306.88"   # total of payments
      assert_text "3,306.88"    # total interest
      assert_text "PAYMENT SCHEDULE" # eyebrow is uppercased by CSS
      assert_text "Paid off"    # the final row clears the balance
    end
    # WORST-CASE stat-grid geometry (frontend agent: "test the worst case"). The `--wide`
    # grid carries high-magnitude money; assert no value wraps mid-number and none clips.
    assert_no_mid_value_wrap("#result dl.stat-grid--wide .stat-card dd")
    assert_no_value_clip("#result dl.stat-grid--wide .stat-card dd")
    screenshot_full_page("62-loan-payment-result")
  end

  test "solves for the affordable loan amount" do
    visit "/calculators/loan"
    choose "Loan amount", allow_label_click: true
    fill_in "Monthly payment", with: "1199.10"
    fill_in "Annual interest rate", with: "6"
    fill_in "Loan term", with: "360"
    click_button "Calculate"
    within "#result" do
      assert_text "Loan amount"
      assert_text "199,999.82" # the solved affordable amount (the hero)
    end
    screenshot_full_page("63-loan-amount-result")
  end

  test "a large loan's wide stat grid renders high-magnitude totals on one line" do
    # The 30y mortgage's total of payments is 6–7 figure money ($431,677.04) — the exact
    # case the --wide track exists for. Prove the worst-case figures hold on one line and
    # never clip in the narrow result panel.
    visit "/calculators/loan"
    fill_in "Loan amount", with: "200000"
    fill_in "Annual interest rate", with: "6"
    fill_in "Loan term", with: "360"
    click_button "Calculate"
    within "#result" do
      assert_text "431,677.04"
    end
    assert_no_mid_value_wrap("#result dl.stat-grid--wide .stat-card dd")
    assert_no_value_clip("#result dl.stat-grid--wide .stat-card dd")
    screenshot_full_page("64-loan-large-result")
  end

  test "invalid input shows the error fragment" do
    visit "/calculators/loan"
    # Submit with no numbers → server 422 → error fragment in #result.
    click_button "Calculate"
    within "#result" do
      # The eyebrow is uppercased by CSS, so the rendered text is "CHECK YOUR INPUT".
      assert_text "CHECK YOUR INPUT"
      assert_selector "[role=alert] li", text: "Loan amount can't be blank"
    end
    screenshot_full_page("65-loan-error")
  end
end
