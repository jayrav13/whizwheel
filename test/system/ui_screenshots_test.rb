require "application_system_test_case"

# Drives the real browser through every changed UI state, asserting the key content
# and saving a full-page screenshot of each to tmp/screenshots/. Doubles as a
# regression check (the assertions) and a visual-verification artifact (the PNGs,
# which CI uploads and the frontend agent reviews against docs/DESIGN.md).
class UiScreenshotsTest < ApplicationSystemTestCase
  test "anonymous home" do
    visit root_path
    assert_text "Every answer, computed"
    assert_selector "a", text: "Sign in"
    screenshot_full_page("01-home-anonymous")
  end

  test "login page" do
    visit new_session_path
    assert_selector "h1", text: "Sign in"
    assert_field "Username"
    assert_field "Password"
    screenshot_full_page("02-login")
  end

  test "failed login alert" do
    sign_in_as("alice", "wrong")
    assert_selector "[role=alert]", text: "Invalid username or password."
    screenshot_full_page("03-login-failed")
  end

  test "signed-in home" do
    sign_in_as("alice", "password")
    assert_selector "h1", text: "Signed in as alice"
    assert_selector "nav", text: "Sign out"
    screenshot_full_page("04-home-signed-in")
  end
end
