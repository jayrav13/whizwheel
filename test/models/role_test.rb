require "test_helper"

class RoleTest < ActiveSupport::TestCase
  test "user is admin with a kept ADMIN role" do
    assert users(:alice).admin?
  end

  test "user is not admin once the role is discarded" do
    roles(:alice_admin).discard
    assert_not users(:alice).reload.admin?
  end

  test "user without an admin role is not admin" do
    assert_not users(:bob).admin?
  end
end
