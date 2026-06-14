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

  test "calculators:ingest populates the registry from docs/INVENTORY.md" do
    out, = capture_io { run_task("calculators:ingest") }
    assert_match(/upserted=8/, out)
    assert Calculator.find_by(slug: "percentage")
    assert_equal 8, Calculator.active.count
  end

  test "calculators:ingest is idempotent" do
    capture_io { run_task("calculators:ingest") }
    count = Calculator.count
    capture_io { run_task("calculators:ingest") }
    assert_equal count, Calculator.count
  end
end
