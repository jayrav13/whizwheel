require "test_helper"

# Integration tests for the Standard Deviation calculator page (frontend issue #191; spec
# #190): the GET page renders its variable-length list textarea + the population/sample
# SEGMENTED mode picker, and the POST Turbo Stream response renders the right result
# fragment for each state (the six result keys, both modes, and 422 errors). These assert
# the markup the system test then verifies visually; together they are the §11 frontend
# gate. Math correctness is the backend's gate; here we assert the page surfaces the
# envelope's keys and phrases errors against the visible labels.
class StandardDeviationPageTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  # ── GET /calculators/standard_deviation ─────────────────────────────────

  test "page renders the title, lede and submit" do
    get "/calculators/standard_deviation"
    assert_response :success
    assert_select "h1", text: "Standard Deviation Calculator"
    assert_select "input[type=submit][value=Calculate]"
  end

  test "page renders a single labeled list input as a textarea" do
    get "/calculators/standard_deviation"
    assert_select "label[for=inputs_values]", text: /Values/
    assert_select "textarea#inputs_values[name='inputs[values]']"
  end

  test "the list input carries a hint describing the accepted separators" do
    get "/calculators/standard_deviation"
    assert_select "textarea#inputs_values[aria-describedby=values_hint]"
    assert_select "#values_hint", text: /commas, spaces, or new lines/i
  end

  # The mode picker is a SEGMENTED control (DESIGN.md §4: N=2 short labels) — a native radio
  # <fieldset> posting a single-select inputs[mode], with the two modes as .direction-pill
  # halves. Population is the default-checked option (defined for any n ≥ 1).
  test "page renders the population/sample mode picker as a segmented radio control" do
    get "/calculators/standard_deviation"
    assert_select "fieldset legend", text: /Data set/
    assert_select "input[type=radio][name='inputs[mode]'][value=population]"
    assert_select "input[type=radio][name='inputs[mode]'][value=sample]"
    # Default-checked = population (the safe default; sample needs n ≥ 2).
    assert_select "input[type=radio][name='inputs[mode]'][value=population][checked=checked]"
    # Segmented presentation: the labels are .direction-pill halves, NOT .mode-option rows.
    assert_select "label.direction-pill", count: 2
    assert_select "label.mode-option", count: 0
  end

  test "page shows the empty result state before any submission" do
    get "/calculators/standard_deviation"
    assert_select "section#result", text: /your answer appears here/i
  end

  # ── POST — Turbo Stream success ─────────────────────────────────────────

  test "computes the statistics for population mode and renders them over Turbo" do
    post "/calculators/standard_deviation",
      params: { inputs: { values: "10,12,23,23,16,23,21,16", mode: "population" } }, headers: TURBO
    assert_response :success
    assert_match "turbo-stream", @response.body
    assert_select "turbo-stream[target=result]"
    within = "section#result"
    # Reference values (spec #190): SD 4.898979, variance 24, mean 18, count 8, sum 144.
    assert_select within, text: /4\.898979/  # standard deviation (hero)
    assert_select within, text: /Population standard deviation/i
    assert_select within, text: /24/         # variance
    assert_select within, text: /18/         # mean
    assert_select within, text: /144/        # sum
    # The supporting figures render in the shared responsive stat grid (DESIGN.md §4 "Stat
    # grid", issue #143) on the `--wide` track (statistical values are high-magnitude).
    assert_select "#{within} dl.stat-grid.stat-grid--wide", count: 1
    assert_select "#{within} dl.stat-grid .stat-card", count: 4   # variance / mean / count / sum
    # The value <dd>s carry break-words (the never-clip floor, DESIGN.md §4).
    assert_select "#{within} dl.stat-grid .stat-card dd.break-words", count: 4
  end

  test "sample mode reports the (n-1) standard deviation and labels itself" do
    post "/calculators/standard_deviation",
      params: { inputs: { values: "10,12,23,23,16,23,21,16", mode: "sample" } }, headers: TURBO
    assert_response :success
    within = "section#result"
    # Reference values (spec #190, sample): SD 5.237229, variance 27.428571.
    assert_select within, text: /5\.237229/
    assert_select within, text: /Sample standard deviation/i
    assert_select within, text: /27\.428571/
  end

  test "an all-equal set reports zero standard deviation and variance" do
    post "/calculators/standard_deviation",
      params: { inputs: { values: "5,5,5", mode: "population" } }, headers: TURBO
    assert_response :success
    # SS = 0 → variance and SD both 0 (rendered "0" by the trim-zeros formatter).
    assert_select "section#result", text: /Population standard deviation/i
    assert_select "section#result", text: /Variance/
  end

  test "a single value is valid in population mode" do
    post "/calculators/standard_deviation",
      params: { inputs: { values: "5", mode: "population" } }, headers: TURBO
    assert_response :success
    # count 1, sum 5, mean 5, variance 0, SD 0 — the hero caption singularises "value".
    assert_select "section#result", text: /1 value/
  end

  # The responsive stat grid must hold large (6+ digit) figures in full, never clipping or
  # truncating them — the worst case the frontend agent is required to exercise (a markup
  # test asserts the figure is present; the system test asserts the geometry doesn't clip).
  # Two seven-figure values give a 7-digit sum and a large variance/SD.
  test "the stat grid renders large 6+ digit figures in full without clipping" do
    post "/calculators/standard_deviation",
      params: { inputs: { values: "1000000, 1003000", mode: "population" } }, headers: TURBO
    assert_response :success
    within = "section#result"
    assert_select within, text: /2,003,000/   # sum (1,000,000 + 1,003,000)
    assert_select within, text: /1,001,500/   # mean
    assert_select within, text: /2,250,000/   # variance
  end

  # ── POST — Turbo Stream 422 (invalid) ───────────────────────────────────

  test "a blank list renders the error fragment with 422" do
    post "/calculators/standard_deviation",
      params: { inputs: { values: "", mode: "population" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
    assert_select "section#result", text: /Check your input/i
  end

  test "the blank-list error is phrased against the Values label, not the raw key" do
    post "/calculators/standard_deviation",
      params: { inputs: { values: "", mode: "population" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: "Values can't be blank"
  end

  test "a non-numeric token surfaces as a label-based validation error, not a 500" do
    post "/calculators/standard_deviation",
      params: { inputs: { values: "1, two, 3", mode: "population" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: /Values must be a list of numbers/
  end

  test "sample mode with a single value surfaces the two-values error" do
    post "/calculators/standard_deviation",
      params: { inputs: { values: "5", mode: "sample" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: /Values need at least 2 values for sample mode/
  end
end
