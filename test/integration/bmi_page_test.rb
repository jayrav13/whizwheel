require "test_helper"

# Integration tests for the BMI calculator page (issue #53): the GET page renders its
# unit-system modes and weight/height fields, and the POST Turbo Stream response renders
# the right result fragment for each state (the BMI number + WHO category, and 422
# errors). These assert the markup the system test then verifies visually; together they
# are the §11 frontend gate. Math correctness is the backend's gate; here we assert the
# page surfaces the envelope's `bmi` + `category` keys.
class BmiPageTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  # ── GET /calculators/bmi ────────────────────────────────────────────────

  test "page renders the title, lede and submit" do
    get "/calculators/bmi"
    assert_response :success
    assert_select "h1", text: "BMI Calculator"
    assert_select "input[type=submit][value=Calculate]"
  end

  test "page renders both unit-system options" do
    get "/calculators/bmi"
    assert_select "input[type=radio][name='inputs[unit_system]'][value=us]"
    assert_select "input[type=radio][name='inputs[unit_system]'][value=metric]"
  end

  test "page renders the weight field with a label" do
    get "/calculators/bmi"
    assert_select "label[for=inputs_weight]", text: /Weight/
    assert_select "input[name='inputs[weight]']"
  end

  test "page renders the metric centimetres height field with a label" do
    get "/calculators/bmi"
    assert_select "label[for=inputs_height_cm]", text: /Height/
    assert_select "input#inputs_height_cm[name='inputs[height]']"
  end

  test "page renders the US total-inches height field as the no-JS baseline" do
    get "/calculators/bmi"
    assert_select "label[for=inputs_height_in]", text: /Total height in inches/
    assert_select "input#inputs_height_in[name='inputs[height]']"
  end

  test "page renders feet and inches helper fields that are never posted (no name)" do
    get "/calculators/bmi"
    # The ft/in helpers exist for the JS-enhanced path but carry no name attribute,
    # so a no-JS submit never sends them — only the canonical inputs[height] posts.
    assert_select "input#inputs_height_feet:not([name])"
    assert_select "input#inputs_height_inches:not([name])"
  end

  test "page wires the Stimulus bmi controller" do
    get "/calculators/bmi"
    assert_select "form[data-controller=bmi]"
  end

  test "page shows the empty result state before any submission" do
    get "/calculators/bmi"
    assert_select "section#result", text: /your answer appears here/i
  end

  # ── POST /calculators/bmi — Turbo Stream success ────────────────────────

  test "US calculation renders the BMI number and WHO category" do
    post "/calculators/bmi", params: { inputs: { unit_system: "us", weight: "160", height: "70" } }, headers: TURBO
    assert_response :success
    assert_match "turbo-stream", @response.body
    assert_select "turbo-stream[target=result]"
    assert_select "section#result", text: /23\.0/
    assert_select "section#result", text: /Normal/
  end

  test "metric calculation renders the BMI number and WHO category" do
    post "/calculators/bmi", params: { inputs: { unit_system: "metric", weight: "72.57", height: "177.8" } }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /23\.0/
    assert_select "section#result", text: /Normal/
  end

  test "an obese-range calculation renders the precise WHO band text" do
    post "/calculators/bmi", params: { inputs: { unit_system: "metric", weight: "95", height: "165" } }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /34\.9/
    assert_select "section#result", text: /Obese Class I/
  end

  test "the result renders the WHO classification scale legend" do
    post "/calculators/bmi", params: { inputs: { unit_system: "us", weight: "160", height: "70" } }, headers: TURBO
    assert_response :success
    # All four broad bins are present as text so the band never relies on color alone.
    %w[Underweight Normal Overweight Obese].each do |bin|
      assert_select "section#result", text: /#{bin}/
    end
  end

  # ── POST /calculators/bmi — Turbo Stream 422 (invalid) ──────────────────

  test "missing required inputs render the error fragment with 422" do
    post "/calculators/bmi", params: { inputs: { unit_system: "metric", weight: "", height: "" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
    assert_select "section#result", text: /Check your input/i
  end

  test "errors are phrased against the field's visible label, not the raw key" do
    post "/calculators/bmi", params: { inputs: { unit_system: "metric", weight: "", height: "" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: "Weight can't be blank"
    assert_select "section#result [role=alert] li", text: "Height can't be blank"
  end

  test "a non-positive measurement surfaces as a validation error, not a 500" do
    post "/calculators/bmi", params: { inputs: { unit_system: "us", weight: "0", height: "70" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
  end
end
