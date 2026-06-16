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
    # The catalog is registry-driven (issue #107): one card per active calculator,
    # rendered from the registry's metadata (name + category eyebrow). Assert the grid
    # actually painted the full library, not an empty/hand-listed set.
    Calculator.active.find_each do |calc|
      assert_selector "a[href='/calculators/#{calc.slug}']", text: calc.name
    end
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
    sign_in_as("alice", "wrong", expect_success: false)
    assert_selector "[role=alert]", text: "Invalid username or password."
    screenshot_full_page("03-login-failed")
  end

  test "signed-in home" do
    sign_in_as("alice", "password")
    assert_selector "h1", text: "Signed in as alice"
    assert_selector "nav", text: "Sign out"
    screenshot_full_page("04-home-signed-in")
  end

  # Inter is self-hosted (issue #11) — before the fix it was named in --font-sans
  # but never delivered, so every non-macOS visitor silently fell back. Assert the
  # @font-face actually loaded so the BLEND grotesk (DESIGN.md §2) reaches the page,
  # not just that the family is *named* in CSS.
  test "Inter web font is delivered" do
    visit root_path
    assert_selector "h1"
    # The Font Loading API resolves once the @font-face woff2 has loaded.
    page.document.synchronize do
      ready = page.evaluate_script("document.fonts.ready.then(() => true)")
      assert ready, "document.fonts.ready did not resolve"
    end
    loaded = page.evaluate_script("document.fonts.check('800 16px Inter')")
    assert loaded, "Inter @font-face did not load — the self-hosted woff2 is not being delivered"
  end
end
