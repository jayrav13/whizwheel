require "test_helper"

# Issue #107 — convention-based frontend discovery: the home catalog is driven by the
# registry, the result region dispatches to a per-slug partial with a generic fallback,
# and field labels resolve per-calculator. These assert the new wiring renders correctly
# from fixtures (the registry's test source).
class RegistryFrontendTest < ActionDispatch::IntegrationTest
  # ── Registry-driven catalog ───────────────────────────────────────────────

  test "the home catalog renders one card per active registry calculator" do
    get root_path
    assert_response :success

    Calculator.active.find_each do |calc|
      # Each active calculator gets a card linking to its page by slug, leading with the
      # registry's category eyebrow + name + description blurb.
      assert_select "a[href=?]", "/calculators/#{calc.slug}", { count: 1 } do
        assert_select "p.text-accent.uppercase", text: calc.category
        assert_select "h2", text: calc.name
        assert_select "p", text: calc.description
      end
    end
  end

  test "the home catalog never renders a deprecated calculator" do
    get root_path
    assert_response :success
    # The deprecated fixture row (retired_thing) is excluded by the .active scope.
    assert_select "a[href=?]", "/calculators/retired_thing", { count: 0 }
  end

  test "the home catalog cards are ordered by category then name" do
    get root_path
    assert_response :success

    expected = Calculator.active.order(:category, :name).map { |c| "/calculators/#{c.slug}" }
    rendered = css_select("a[href^='/calculators/']").map { |a| a["href"] }
    assert_equal expected, rendered
  end

  # ── Result-dispatch convention ─────────────────────────────────────────────

  test "a calculator with a per-slug result partial renders its bespoke hero" do
    # Percentage has _percentage.html.erb — its bespoke hero carries the detail sentence.
    post "/calculators/percentage",
      params: { inputs: { mode: "percent_of", v1: "50", percent: "20" } },
      as: :turbo_stream
    assert_response :success
    assert_match "20% of 50", response.body
  end

  test "the empty result state renders before any calculation" do
    get "/calculators/percentage"
    assert_response :success
    assert_select "#result p.text-faint", text: "Result"
  end

  test "the validation-error state phrases messages against the visible labels" do
    post "/calculators/percentage",
      params: { inputs: { mode: "percent_of", v1: "", percent: "" } },
      as: :turbo_stream
    assert_response :unprocessable_entity
    # The message leads with the field's visible label (the apostrophe is HTML-escaped in
    # the turbo-stream body, so assert on the label-led prefix DESIGN.md §4 requires).
    assert_match "Value (V1) can", response.body
    assert_match "Percent (P) can", response.body
    # Never the raw attribute key.
    assert_no_match(/\bv1 can/, response.body)
  end
end
