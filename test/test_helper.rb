require "simplecov"
SimpleCov.start "rails" do
  enable_coverage :branch
  add_filter "/test/"
  add_filter "/config/"
  # The 100% gate applies to the unit/integration suite (`bin/rails test`). System
  # tests run as a separate pass (`test:system`) and can't exercise every line, so
  # they opt out via NO_COVERAGE to avoid a false gate failure.
  minimum_coverage line: 100, branch: 100 unless ENV["NO_COVERAGE"]
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
