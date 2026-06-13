require "test_helper"

class CalculationTest < ActiveSupport::TestCase
  test "persists inputs and result as jsonb and may be anonymous" do
    calc = Calculation.create!(calculator: "percentage", inputs: { base: "50", rate: "20" }, result: { value: "10.0" })
    assert_nil calc.user
    assert_equal "20", calc.reload.inputs["rate"]
    assert_equal "10.0", calc.result["value"]
  end

  test "may belong to a user" do
    calc = Calculation.create!(calculator: "percentage", user: users(:alice), inputs: {}, result: {})
    assert_equal users(:alice), calc.user
  end

  test "is soft-deletable" do
    calc = calculations(:anon_pct)
    calc.discard
    assert_not_includes Calculation.kept, calc
  end

  test "calculation_logs view exposes the username" do
    row = ActiveRecord::Base.connection.select_one(
      "SELECT username FROM calculation_logs WHERE id = #{calculations(:alice_pct).id}"
    )
    assert_equal "alice", row["username"]
  end
end
