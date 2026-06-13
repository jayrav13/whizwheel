require "test_helper"

class ApplicationMailerTest < ActiveSupport::TestCase
  test "ApplicationMailer inherits from ActionMailer::Base" do
    assert_equal ActionMailer::Base, ApplicationMailer.superclass
  end
end
