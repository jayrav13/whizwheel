require "test_helper"

# Functional tests for Admin::StatsController#show — the ADMIN gate (404 for
# anonymous + non-admin, 200 for admins) and the @stats assignment.
#
# ActionController::TestCase (not Integration) so prepend_view_path scopes to THIS
# @controller instance only — an integration test's ApplicationController.prepend_view_path
# leaks process-wide and shadows real calculator views. The real dashboard view is
# the frontend's (#221, not yet built), so we render the stub at
# test/support/views/admin/stats/show.html.erb to exercise the 200 render branch
# without crossing the FE/BE seam — mirroring CalculatorsControllerFunctionalTest.
class Admin::StatsControllerTest < ActionController::TestCase
  tests Admin::StatsController

  setup do
    @controller.prepend_view_path Rails.root.join("test/support/views")
  end

  # --- the admin gate (require_admin! → 404) ------------------------------

  test "anonymous visitor gets 404 (the admin area is invisible)" do
    get :show
    assert_response :not_found
  end

  test "a signed-in non-admin user gets 404" do
    sign_in_as users(:bob) # bob has no ADMIN role
    get :show
    assert_response :not_found
  end

  # --- the admin success path --------------------------------------------

  test "an admin user gets 200 and the page renders @stats" do
    sign_in_as users(:alice) # alice has the ADMIN role (roles fixture)
    get :show

    assert_response :success
    # The stub view renders "@stats.volume[:all_time]" — proves the action assigned
    # a working CalculationStats and the page rendered for an admin.
    assert_includes @response.body, "admin stats page"
    # all_time counts the FULL table (§6): 7 kept + 1 discarded = 8.
    assert_includes @response.body, "all-time: 8"
  end

  private

  # Establish a logged-in session the way the app does: Authentication#resume_session
  # reads cookies.signed[:session_id]. Setting the signed jar entry makes the
  # controller resolve Current.session → Current.user.
  def sign_in_as(user)
    session = user.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
    @request.cookie_jar.signed[:session_id] = session.id
  end
end
