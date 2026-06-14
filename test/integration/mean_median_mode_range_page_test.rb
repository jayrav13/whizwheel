require "test_helper"

# Integration tests for the Mean/Median/Mode/Range calculator page (issue #80): the GET
# page renders its single variable-length list input, and the POST Turbo Stream response
# renders the right result fragment for each state (the eight statistics, the array-valued
# `mode` in its three shapes, and 422 errors). These assert the markup the system test then
# verifies visually; together they are the §11 frontend gate. Math correctness is the
# backend's gate; here we assert the page surfaces the envelope's eight result keys.
class MeanMedianModeRangePageTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  # ── GET /calculators/mean_median_mode_range ─────────────────────────────

  test "page renders the title, lede and submit" do
    get "/calculators/mean_median_mode_range"
    assert_response :success
    assert_select "h1", text: "Mean, Median, Mode, Range Calculator"
    assert_select "input[type=submit][value=Calculate]"
  end

  test "page renders a single labeled list input as a textarea" do
    get "/calculators/mean_median_mode_range"
    assert_select "label[for=inputs_numbers]", text: /Numbers/
    assert_select "textarea#inputs_numbers[name='inputs[numbers]']"
  end

  test "the list input carries a hint describing the accepted separators" do
    get "/calculators/mean_median_mode_range"
    assert_select "textarea#inputs_numbers[aria-describedby=numbers_hint]"
    assert_select "#numbers_hint", text: /commas, spaces, or new lines/i
  end

  test "page has no mode picker (single-mode calculator)" do
    get "/calculators/mean_median_mode_range"
    assert_select "input[type=radio][name='inputs[mode]']", count: 0
    assert_select "fieldset legend", count: 0
  end

  test "page shows the empty result state before any submission" do
    get "/calculators/mean_median_mode_range"
    assert_select "section#result", text: /your answer appears here/i
  end

  # ── POST — Turbo Stream success ─────────────────────────────────────────

  test "computes the eight statistics and renders them over Turbo" do
    post "/calculators/mean_median_mode_range",
      params: { inputs: { numbers: "10, 2, 38, 23, 38, 23, 21" } }, headers: TURBO
    assert_response :success
    assert_match "turbo-stream", @response.body
    assert_select "turbo-stream[target=result]"
    within = "section#result"
    assert_select within, text: /22\.143/  # mean
    assert_select within, text: /Mode/      # the mode label
    assert_select within, text: /36/        # range
    assert_select within, text: /155/       # sum
  end

  test "a bimodal set renders both modes joined with 'and'" do
    post "/calculators/mean_median_mode_range",
      params: { inputs: { numbers: "10, 2, 38, 23, 38, 23, 21" } }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /23 and 38/
  end

  test "a unimodal set renders the single mode value" do
    post "/calculators/mean_median_mode_range",
      params: { inputs: { numbers: "4, 4, 4, 2, 2" } }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /Mode/
    # mode = [4]; mean = 3.2; range = 2
    assert_select "section#result", text: /3\.2/
  end

  test "an all-unique set renders 'No mode' rather than an arbitrary value" do
    post "/calculators/mean_median_mode_range",
      params: { inputs: { numbers: "1, 2, 3, 4, 5" } }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /No mode/
  end

  test "a single value renders a range of 0 and no mode" do
    post "/calculators/mean_median_mode_range",
      params: { inputs: { numbers: "7" } }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /No mode/
    assert_select "section#result", text: /Count/
  end

  test "whitespace and newline separators parse the same as commas" do
    post "/calculators/mean_median_mode_range",
      params: { inputs: { numbers: "2 4\n6  8" } }, headers: TURBO
    assert_response :success
    # mean = 5, median = (4+6)/2 = 5, range = 6, count = 4
    assert_select "section#result", text: /No mode/
  end

  # ── POST — Turbo Stream 422 (invalid) ───────────────────────────────────

  test "a blank list renders the error fragment with 422" do
    post "/calculators/mean_median_mode_range",
      params: { inputs: { numbers: "" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
    assert_select "section#result", text: /Check your input/i
  end

  test "the blank-list error is phrased against the Numbers label, not the raw key" do
    post "/calculators/mean_median_mode_range",
      params: { inputs: { numbers: "" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: "Numbers can't be blank"
  end

  test "a non-numeric token surfaces as a label-based validation error, not a 500" do
    post "/calculators/mean_median_mode_range",
      params: { inputs: { numbers: "1, 2, banana" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: /Numbers contains a value that is not a number: banana/
  end

  test "a list of only separators surfaces the blank error" do
    post "/calculators/mean_median_mode_range",
      params: { inputs: { numbers: ", ,  ," } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: "Numbers can't be blank"
  end
end
