require "test_helper"

# Integration tests for the Date calculator page (issue #195): the GET page renders the
# mode picker + both modes' fields, and the POST Turbo Stream response renders the right
# result fragment for each state (the difference Y/M/D breakdown + totals, the add_subtract
# resulting date, and 422 errors). These assert the markup the system test then verifies
# visually; together they are the §11 frontend gate. Math correctness is the backend's gate;
# here we assert the page surfaces the envelope's output keys for each mode.
class DatePageTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  # ── GET /calculators/date ────────────────────────────────────────────────

  test "page renders the title, lede and submit" do
    get "/calculators/date"
    assert_response :success
    assert_select "h1", text: "Date Calculator"
    assert_select "input[type=submit][value='Calculate']"
  end

  test "the mode picker is a native radio fieldset .mode-option list (DESIGN §4)" do
    get "/calculators/date"
    # Two multi-word modes → the selectable option list, not a segmented control.
    assert_select "fieldset legend", text: /What do you want to calculate/i
    assert_select "label.mode-option", count: 2
    assert_select "input[type=radio][name='inputs[mode]'][value=difference]"
    assert_select "input[type=radio][name='inputs[mode]'][value=add_subtract]"
    # Default mode is the first option (difference).
    assert_select "input[type=radio][name='inputs[mode]'][value=difference][checked]"
  end

  test "the difference mode renders two date fields with labels" do
    get "/calculators/date"
    assert_select "label[for=inputs_start_date_diff]", text: /Start date/
    assert_select "input[type=date]#inputs_start_date_diff[name='inputs[start_date]']"
    assert_select "label[for=inputs_end_date]", text: /End date/
    assert_select "input[type=date]#inputs_end_date[name='inputs[end_date]']"
  end

  test "the add_subtract mode renders a start date, the operation segmented control and offsets" do
    get "/calculators/date"
    # A second start_date field (the add_subtract block's), distinct id.
    assert_select "input[type=date]#inputs_start_date_add[name='inputs[start_date]']"
    # Operation — a SEGMENTED CONTROL (.direction-pill), N=2 short labels (DESIGN §4 picker rule).
    assert_select "label.direction-pill", count: 2
    assert_select "input[type=radio][name='inputs[operation]'][value=add][checked]"
    assert_select "input[type=radio][name='inputs[operation]'][value=subtract]"
    # The four unsigned integer offset fields.
    %w[years months weeks days].each do |key|
      assert_select "input[type=number]#inputs_#{key}[name='inputs[#{key}]'][min='0']"
    end
  end

  test "the add_subtract block is hidden by default (difference is the default mode)" do
    get "/calculators/date"
    assert_select "div[data-date-modes=add_subtract][hidden]"
    assert_select "div[data-date-modes=difference]:not([hidden])"
  end

  test "the form is wired to the date Stimulus controller" do
    get "/calculators/date"
    assert_select "form[data-controller=date]"
  end

  test "no date field carries a Today quick-fill (both are required primary dates, DESIGN §4)" do
    get "/calculators/date"
    # start_date / end_date are required primary inputs — no "today" meaning, so no quick-fill.
    assert_select "button[data-action='date#today']", count: 0
    assert_select "button", text: "Today", count: 0
  end

  test "page shows the empty result state before any submission" do
    get "/calculators/date"
    assert_select "section#result", text: /your answer appears here/i
  end

  # ── POST /calculators/date — difference mode (Turbo Stream success) ───────

  test "a valid difference renders the Y/M/D breakdown, totals and weeks view" do
    post "/calculators/date",
      params: { inputs: { mode: "difference", start_date: "2023-01-15", end_date: "2025-03-20" } },
      headers: TURBO
    assert_response :success
    assert_match "turbo-stream", @response.body
    assert_select "turbo-stream[target=result]"
    # The breakdown — 2 years, 2 months, 5 days.
    assert_select "section#result", text: /2 years · 2 months · 5 days/
    # The totals + weeks-and-days view.
    assert_select "section#result", text: /Total days/i
    assert_select "section#result", text: /795/
    assert_select "section#result", text: /113 weeks and 4 days/
  end

  test "a difference renders the shared stat grid with the wide track (large day counts)" do
    post "/calculators/date",
      params: { inputs: { mode: "difference", start_date: "2023-01-15", end_date: "2025-03-20" } },
      headers: TURBO
    assert_response :success
    # The shared responsive stat grid (DESIGN §4, issue #143), wide track for unbounded day
    # counts; never an inline grid-cols width. Three totals (days / weeks / remaining days).
    assert_select "section#result dl.stat-grid.stat-grid--wide", count: 1
    assert_select "section#result dl.stat-grid .stat-card", count: 3
    assert_select "section#result dl.stat-grid .stat-card dd.break-words.tabular-nums", count: 3
  end

  test "a multi-century difference renders a 6+ digit day count in full (clipping guard)" do
    # DESIGN §4 "Stat grid": the grid must never clip a value. A ~272-year span gives a
    # six-digit total_days — assert it renders delimited and in full on the wide track.
    post "/calculators/date",
      params: { inputs: { mode: "difference", start_date: "1753-01-01", end_date: "2025-01-01" } },
      headers: TURBO
    assert_response :success
    assert_select "section#result", text: /99,346/   # total_days, six digits, delimited, in full
  end

  test "an out-of-order difference reports the magnitude (order-independent)" do
    post "/calculators/date",
      params: { inputs: { mode: "difference", start_date: "2025-03-20", end_date: "2023-01-15" } },
      headers: TURBO
    assert_response :success
    assert_select "section#result", text: /2 years · 2 months · 5 days/
    assert_select "section#result", text: /795/
  end

  # ── POST /calculators/date — add_subtract mode (Turbo Stream success) ─────

  test "a valid add renders the resulting date with a long-format echo" do
    post "/calculators/date",
      params: { inputs: { mode: "add_subtract", start_date: "2024-01-01", operation: "add",
                          years: "0", months: "0", weeks: "0", days: "30" } },
      headers: TURBO
    assert_response :success
    assert_select "turbo-stream[target=result]"
    assert_select "section#result", text: /Resulting date/i
    assert_select "section#result", text: /2024-01-31/
    # The long human date echo.
    assert_select "section#result", text: /Wednesday, January 31, 2024/
    # The echoed inputs.
    assert_select "section#result", text: /Start date/i
    assert_select "section#result", text: /2024-01-01/
  end

  test "a subtract with end-of-month clamping renders the clamped result date" do
    post "/calculators/date",
      params: { inputs: { mode: "add_subtract", start_date: "2023-01-31", operation: "add",
                          years: "0", months: "1", weeks: "0", days: "0" } },
      headers: TURBO
    assert_response :success
    assert_select "section#result", text: /2023-02-28/
    assert_select "section#result", text: /Operation/i
    assert_select "section#result", text: /add/i
  end

  test "the add_subtract echo grid is the shared stat grid (default track)" do
    post "/calculators/date",
      params: { inputs: { mode: "add_subtract", start_date: "2024-01-01", operation: "subtract",
                          years: "0", months: "0", weeks: "0", days: "1" } },
      headers: TURBO
    assert_response :success
    assert_select "section#result", text: /2023-12-31/
    assert_select "section#result dl.stat-grid", count: 1
    assert_select "section#result dl.stat-grid:not(.stat-grid--wide)", count: 1
    assert_select "section#result dl.stat-grid .stat-card", count: 2
  end

  # ── POST /calculators/date — Turbo Stream 422 (invalid) ──────────────────

  test "a difference missing the end date renders the error fragment with 422" do
    post "/calculators/date",
      params: { inputs: { mode: "difference", start_date: "2024-01-01", end_date: "" } },
      headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert]"
    assert_select "section#result", text: /Check your input/i
  end

  test "errors are phrased against the field's visible label, not the raw key" do
    post "/calculators/date",
      params: { inputs: { mode: "difference", start_date: "2024-01-01", end_date: "" } },
      headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: "End date can't be blank"
  end

  test "an add_subtract missing the operation surfaces a label-based validation error" do
    post "/calculators/date",
      params: { inputs: { mode: "add_subtract", start_date: "2024-01-01", operation: "",
                          years: "0", months: "0", weeks: "0", days: "0" } },
      headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: "Operation can't be blank"
  end

  test "an unparseable start date surfaces a label-based validation error, not a 500" do
    post "/calculators/date",
      params: { inputs: { mode: "difference", start_date: "2023-02-30", end_date: "2024-01-01" } },
      headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: "Start date is not a valid date"
  end

  test "an unknown mode surfaces a label-based validation error" do
    post "/calculators/date",
      params: { inputs: { mode: "zzz", start_date: "2024-01-01", end_date: "2024-02-01" } },
      headers: TURBO
    assert_response :unprocessable_entity
    assert_select "section#result [role=alert] li", text: /Calculation is not included in the list/
  end
end
