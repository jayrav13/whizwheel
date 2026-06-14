require "test_helper"
require "active_support/testing/time_helpers"

# Integration tests for the Age calculator page (issue #82): the GET page renders its two
# date fields (no mode picker), and the POST Turbo Stream response renders the right
# result fragment for each state (the Y/M/D breakdown + the four total-unit conversions,
# and 422 errors). These assert the markup the system test then verifies visually;
# together they are the §11 frontend gate. Math correctness is the backend's gate; here we
# assert the page surfaces the envelope's seven output keys.
class AgePageTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  # ── GET /calculators/age ────────────────────────────────────────────────

  test "page renders the title, lede and submit" do
    get "/calculators/age"
    assert_response :success
    assert_select "h1", text: "Age Calculator"
    assert_select "input[type=submit][value='Calculate age']"
  end

  test "page renders the two date fields with labels" do
    get "/calculators/age"
    assert_select "label[for=inputs_birth_date]", text: /Date of birth/
    assert_select "input[type=date]#inputs_birth_date[name='inputs[birth_date]']"
    assert_select "label[for=inputs_end_date]", text: /Age at the date of/
    assert_select "input[type=date]#inputs_end_date[name='inputs[end_date]']"
  end

  test "the end-date field is signalled optional with a defaults-to-today note" do
    get "/calculators/age"
    assert_select "p", text: /defaults to today/i
  end

  test "page has no mode picker (Age has no input mode)" do
    get "/calculators/age"
    # The spec's multi-mode tag is about output representations, not an input selector,
    # so none of the mode-picker vocabularies appear.
    assert_select "fieldset legend", count: 0
    assert_select "label.mode-option", count: 0
    assert_select "label.mode-pill", count: 0
    assert_select "label.direction-pill", count: 0
  end

  test "page shows the empty result state before any submission" do
    get "/calculators/age"
    assert_select "section#result", text: /your answer appears here/i
  end

  # ── POST /calculators/age — Turbo Stream success ────────────────────────

  test "a valid age renders the Y/M/D breakdown and the total-unit conversions" do
    post "/calculators/age",
      params: { inputs: { birth_date: "1990-06-15", end_date: "2024-06-14" } }, headers: TURBO
    assert_response :success
    assert_match "turbo-stream", @response.body
    assert_select "turbo-stream[target=result]"
    # The breakdown — 33 years, 11 months, 30 days.
    assert_select "section#result", text: /33/
    assert_select "section#result", text: /11 months · 30 days/
    # The total-unit conversions, with thousands delimiters.
    assert_select "section#result", text: /Total months/i
    assert_select "section#result", text: /12,418/
    assert_select "section#result", text: /298,032/
  end

  test "an omitted end date defaults to today" do
    travel_to Time.zone.local(2024, 6, 14, 9, 0, 0) do
      post "/calculators/age", params: { inputs: { birth_date: "1990-06-15", end_date: "" } }, headers: TURBO
    end
    assert_response :success
    assert_select "section#result", text: /11 months · 30 days/
  end

  test "a same-day age renders the all-zero breakdown as '0 days'" do
    post "/calculators/age",
      params: { inputs: { birth_date: "2023-03-01", end_date: "2023-03-01" } }, headers: TURBO
    assert_response :success
    assert_select "section#result", text: /0 days old/
  end

  # ── POST /calculators/age — Turbo Stream 422 (invalid) ──────────────────

  test "a missing birth date renders the error fragment with 422" do
    post "/calculators/age", params: { inputs: { birth_date: "", end_date: "2024-01-01" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
    assert_select "section#result", text: /Check your input/i
  end

  test "errors are phrased against the field's visible label, not the raw key" do
    post "/calculators/age", params: { inputs: { birth_date: "", end_date: "2024-01-01" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: "Date of birth can't be blank"
  end

  test "an out-of-order birth date surfaces a label-based validation error, not a 500" do
    post "/calculators/age",
      params: { inputs: { birth_date: "2024-06-15", end_date: "2024-06-14" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: "Date of birth must be on or before the end date"
  end

  test "an unparseable date surfaces a label-based validation error, not a 500" do
    post "/calculators/age",
      params: { inputs: { birth_date: "2023-02-30", end_date: "2024-01-01" } }, headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: "Date of birth is not a valid date"
  end
end
