require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "requires a unique username" do
    dup = User.new(username: users(:alice).username, password: "secret123")
    assert_not dup.valid?
    assert_includes dup.errors[:username], "has already been taken"
  end

  test "normalizes username to stripped lowercase" do
    user = User.create!(username: "  BoB  ", password: "secret123")
    assert_equal "bob", user.username
  end

  test "authenticate_by verifies the password" do
    assert User.authenticate_by(username: "alice", password: "password")
    assert_nil User.authenticate_by(username: "alice", password: "wrong")
  end
end
