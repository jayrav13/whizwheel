require "test_helper"

class UiViewsTest < ActionDispatch::IntegrationTest
  test "signed-out home renders a sign-in affordance" do
    get root_path
    assert_response :success
    assert_select "a[href=?]", new_session_path, text: "Sign in"
  end

  test "signed-in home renders the username and a sign-out control" do
    post session_path, params: { username: "alice", password: "password" }
    follow_redirect!
    assert_response :success
    assert_select "h1", /Signed in as alice/
    assert_select "form[action=?][method=post]", session_path do
      assert_select "input[name=_method][value=delete]", true
      assert_select "button", text: "Sign out"
    end
  end

  test "sessions#new renders the login form with labeled username and password fields" do
    get new_session_path
    assert_response :success
    assert_select "form[action=?]", session_path do
      assert_select "label", text: "Username"
      assert_select "input[name=username][autocomplete=username]"
      assert_select "label", text: "Password"
      assert_select "input[name=password][type=password][autocomplete=current-password]"
      assert_select "input[type=submit][value='Sign in']"
    end
  end

  test "failed login renders the BLEND alert flash" do
    post session_path, params: { username: "alice", password: "wrong" }
    follow_redirect!
    assert_response :success
    assert_select "[role=alert]", /Invalid username or password\./
  end
end
