require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "root page renders for anonymous visitors" do
    get root_path
    assert_response :success
    assert_select "body", /not signed in/i
  end

  test "valid login starts a session and shows the username" do
    post session_path, params: { username: "alice", password: "password" }
    assert_redirected_to root_path
    follow_redirect!
    assert_select "body", /alice/
  end

  test "invalid login is rejected" do
    post session_path, params: { username: "alice", password: "nope" }
    assert_redirected_to new_session_path
  end

  test "logout terminates the session" do
    post session_path, params: { username: "alice", password: "password" }
    delete session_path
    assert_redirected_to root_path
    follow_redirect!
    assert_select "body", /not signed in/i
  end
end
