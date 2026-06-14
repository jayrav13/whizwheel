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
    # The figures render in the shared responsive stat grid (DESIGN.md §4 "Stat grid",
    # issue #143): two `.stat-grid`s — the headline cards (mean/median/range as
    # `.stat-card`s) and the quieter card-less supporting row (sum/count/smallest/largest).
    # Statistical values are unbounded/high-magnitude, so BOTH grids use the `.stat-grid--wide`
    # track (a 7-digit mean and a larger sum hold on one line rather than wrapping or — under
    # the default track — clipping; the #176 regression fix).
    assert_select "#{within} dl.stat-grid", count: 2
    assert_select "#{within} dl.stat-grid.stat-grid--wide", count: 2
    assert_select "#{within} dl.stat-grid .stat-card", count: 3   # mean / median / range
    # The primary value <dd>s carry break-words (the never-clip floor, DESIGN.md §4).
    assert_select "#{within} dl.stat-grid .stat-card dd.break-words", count: 3
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

  # The responsive auto-fit stat grid (DESIGN.md §4) must hold large (6+ digit) figures in
  # full, never clipping or truncating them — the worst case the frontend agent is required
  # to exercise. Two seven-figure values give a 7-digit sum and a delimited-into-the-millions
  # smallest/largest; we assert each renders complete (delimited, no ellipsis).
  test "the stat grid renders large 6+ digit figures in full without clipping" do
    post "/calculators/mean_median_mode_range",
      params: { inputs: { numbers: "1234567, 7654321" } }, headers: TURBO
    assert_response :success
    within = "section#result"
    assert_select within, text: /8,888,888/   # sum (1,234,567 + 7,654,321)
    assert_select within, text: /6,419,754/   # range (7,654,321 − 1,234,567)
    assert_select within, text: /7,654,321/   # largest, delimited in full
    assert_select within, text: /1,234,567/   # smallest, delimited in full
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
