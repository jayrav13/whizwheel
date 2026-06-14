require "simplecov"

# --- Coverage under parallel test workers (#111) ---
#
# Rails' `parallelize` FORKS one worker process per core. SimpleCov tracks
# coverage per-process, so each fork must `SimpleCov.start` under a UNIQUE
# command name and write its own resultset; the results are then MERGED back in
# the main process. Without this, only the (near-empty) main process resultset
# survives and a local run reports a wildly undercounted figure (~11% line /
# 0% branch) even though true coverage is 100% — which fails the gate locally
# for every developer/agent. (CI masked it; the merge is the correct fix for
# both.) The gate is enforced ONCE, against the merged total, in the
# `Minitest.after_run` collate step below — never per-process, since a single
# fork never sees the whole suite.
SimpleCov.command_name("RailsTest")
SimpleCov.start "rails" do
  enable_coverage :branch
  add_filter "/test/"
  add_filter "/config/"
  use_merging true
  # Per-process minimum disabled (set to 0); the merged total is gated below.
  minimum_coverage line: 0, branch: 0
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Each forked worker re-starts SimpleCov under its own command name so its
    # coverage resultset is keyed distinctly and survives merging.
    parallelize_setup do |worker|
      SimpleCov.command_name("RailsTest-worker-#{worker}")
    end

    # Flush each worker's coverage to disk as it finishes so the main process
    # can collate it.
    parallelize_teardown do |_worker|
      SimpleCov.result
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

# In the MAIN process, after the whole suite finishes, collate every process's
# resultset into one merged report and enforce the 100% gate against that merged
# total. NO_COVERAGE opts the system-test pass out of the gate (a browser pass
# can't exercise every line on its own).
unless ENV["NO_COVERAGE"]
  Minitest.after_run do
    resultset = File.expand_path("../coverage/.resultset.json", __dir__)
    SimpleCov.collate([ resultset ]) do
      enable_coverage :branch
      # A slow worker's resultset must never be silently dropped from the merge.
      merge_timeout 3600
      formatter SimpleCov::Formatter::HTMLFormatter
    end

    result = SimpleCov.result
    line   = result.covered_percent
    branch = result.coverage_statistics[:branch]&.percent || 100.0

    if line < 100.0 || branch < 100.0
      warn format(
        "\nMerged coverage below the 100%% gate: line %.2f%%, branch %.2f%%.\n",
        line, branch
      )
      exit 2
    end
  end
end
