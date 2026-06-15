require "test_helper"
require "rake"

class CalculatorsTaskTest < ActiveSupport::TestCase
  setup do
    Whizwheel::Application.load_tasks if Rake::Task.tasks.empty?
    Calculator.delete_all
  end

  def run_task(name, *args)
    task = Rake::Task[name]
    task.reenable
    task.invoke(*args)
  end

  # The ingest upserts exactly the INVENTORY rows whose slug resolves to a
  # Calculators::X class with a description, so the expected count equals the
  # number of built calculator classes on disk (each guaranteed a complete row
  # by the drift test). Derive it so adding a calculator never forces a bump of
  # a shared constant here — a rule-#3 (no central shared edit) collision under
  # the fan-out sweep. Mirrors test/lib/registry/ingest_test.rb's all_built_rows.
  def built_calculator_count
    Dir[Rails.root.join("app/calculators/*.rb")]
      .map { |p| File.basename(p, ".rb") }
      .reject { |s| s == "base" }
      .size
  end

  test "calculators:ingest populates the registry from docs/INVENTORY.md" do
    expected = built_calculator_count
    out, = capture_io { run_task("calculators:ingest") }
    assert_match(/upserted=#{expected}/, out)
    assert Calculator.find_by(slug: "percentage")
    assert_equal expected, Calculator.active.count
  end

  test "calculators:ingest is idempotent" do
    capture_io { run_task("calculators:ingest") }
    count = Calculator.count
    capture_io { run_task("calculators:ingest") }
    assert_equal count, Calculator.count
  end
end
