require "test_helper"

# Integration tests for the Percentage calculator page (issue #31): the GET page
# renders its modes/fields, and the POST Turbo Stream response renders the right
# result fragment for each state (answer + 422 errors). These assert the markup the
# system test then verifies visually; together they are the §11 frontend gate.
class PercentagePageTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  # ── GET /calculators/percentage ─────────────────────────────────────────

  test "page renders the title, lede and submit" do
    get "/calculators/percentage"
    assert_response :success
    assert_select "h1", text: "Percentage Calculator"
    assert_select "input[type=submit][value=Calculate]"
  end

  test "page renders all five mode options" do
    get "/calculators/percentage"
    %w[percent_of what_percent percent_of_what difference change].each do |mode|
      assert_select "input[type=radio][name='inputs[mode]'][value=?]", mode
    end
  end

  test "page renders every per-mode input with a label" do
    get "/calculators/percentage"
    assert_select "label[for=inputs_v1]", text: /Value \(V1\)/
    assert_select "label[for=inputs_v2]", text: /Value \(V2\)/
    assert_select "label[for=inputs_percent]", text: /Percent \(P\)/
    assert_select "input[name='inputs[v1]']"
    assert_select "input[name='inputs[v2]']"
    assert_select "input[name='inputs[percent]']"
  end

  test "page renders the increase/decrease direction toggle for change mode" do
    get "/calculators/percentage"
    assert_select "div[data-percentage-field=change]"
    assert_select "input[type=radio][name='inputs[direction]'][value=increase]"
    assert_select "input[type=radio][name='inputs[direction]'][value=decrease]"
  end

  test "page wires the Stimulus percentage controller" do
    get "/calculators/percentage"
    assert_select "form[data-controller=percentage]"
  end

  test "page shows the empty result state before any submission" do
    get "/calculators/percentage"
    assert_select "section#result", text: /your answer appears here/i
  end

  # ── POST /calculators/percentage — Turbo Stream success ─────────────────

  test "percent_of renders the computed value into the result target" do
    post "/calculators/percentage", params: { inputs: { mode: "percent_of", v1: "50", percent: "20" } }, headers: TURBO
    assert_response :success
    assert_match "turbo-stream", @response.body
    assert_select "turbo-stream[target=result]"
    assert_select "section#result", text: /10\b/
  end

  test "what_percent renders a percent result with a percent sign" do
    post "/calculators/percentage", params: { inputs: { mode: "what_percent", v1: "10", v2: "50" } }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /20%/
  end

  test "change increase renders the new value" do
    post "/calculators/percentage", params: { inputs: { mode: "change", v1: "500", percent: "10", direction: "increase" } }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /550\b/
  end

  test "percent_of_what renders the whole" do
    post "/calculators/percentage", params: { inputs: { mode: "percent_of_what", v1: "10", percent: "20" } }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /50\b/
  end

  test "difference renders the percentage difference" do
    post "/calculators/percentage", params: { inputs: { mode: "difference", v1: "10", v2: "6" } }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /50%/
  end

  # ── POST /calculators/percentage — Turbo Stream 422 (invalid) ───────────

  test "missing required input renders the error fragment with 422" do
    post "/calculators/percentage", params: { inputs: { mode: "percent_of", v1: "", percent: "" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
    assert_select "section#result", text: /Check your input/i
  end

  test "errors are phrased against the field's visible label, not the raw key" do
    post "/calculators/percentage", params: { inputs: { mode: "percent_of", v1: "", percent: "" } }, headers: TURBO
    assert_response :unprocessable_entity
    # The visible label leads — "Value (V1) can't be blank", never "V1 can't be blank".
    assert_select "section#result [role=alert] li", text: "Value (V1) can't be blank"
    assert_select "section#result [role=alert] li", text: "Percent (P) can't be blank"
    assert_select "section#result [role=alert] li", text: /\AV1 /, count: 0
  end

  test "division-by-zero input surfaces as a validation error, not a 500" do
    post "/calculators/percentage", params: { inputs: { mode: "what_percent", v1: "10", v2: "0" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
  end
end
