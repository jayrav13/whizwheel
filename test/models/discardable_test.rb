require "test_helper"

class DiscardableTest < ActiveSupport::TestCase
  test "discard sets deleted_at and removes from kept" do
    role = roles(:alice_admin)
    assert_includes Role.kept, role
    role.discard
    assert role.discarded?
    assert_not_includes Role.kept, role
    assert_includes Role.discarded, role
  end

  test "undiscard restores" do
    role = roles(:alice_admin)
    role.discard
    role.undiscard
    assert_not role.discarded?
    assert_includes Role.kept, role
  end
end
