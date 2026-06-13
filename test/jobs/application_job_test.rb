require "test_helper"

class ApplicationJobTest < ActiveSupport::TestCase
  test "ApplicationJob inherits from ActiveJob::Base" do
    assert_equal ActiveJob::Base, ApplicationJob.superclass
  end
end
