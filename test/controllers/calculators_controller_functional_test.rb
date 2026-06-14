require "test_helper"
require_relative "../support/calculators"

# Functional controller tests (ActionController::TestCase) for the page-serving
# branches whose REAL templates are the frontend's (calculators/<slug>,
# calculators/create.turbo_stream.erb — issue #31, not yet built). To exercise the
# controller's render branches without writing app/views (the FE/BE seam), these
# tests prepend a test-only view path (test/support/views) holding minimal stubs for
# the TestDouble calculator — so the action runs end-to-end and every respond_to
# branch is covered for the 100% gate. The JSON envelope + persistence stay on the
# integration suite (calculators_controller_test.rb).
class CalculatorsControllerFunctionalTest < ActionController::TestCase
  tests CalculatorsController

  setup do
    @controller.prepend_view_path Rails.root.join("test/support/views")
  end

  # --- show ---------------------------------------------------------------

  test "show renders the calculator's page view for a known slug" do
    get :show, params: { slug: "test_double" }

    assert_response :success
    # The stub calculators/test_double page rendered — i.e. show resolved the slug
    # to a calculator and rendered its page view (the real view is the FE's, #31).
    assert_includes @response.body, "test_double page"
  end

  test "show is 404 for an unknown slug" do
    get :show, params: { slug: "no_such_calculator" }
    assert_response :not_found
  end

  # --- create: turbo_stream branches --------------------------------------

  test "create renders the turbo_stream fragment for valid input" do
    @request.headers["Accept"] = Mime[:turbo_stream].to_s
    post :create, params: { slug: "test_double", inputs: { x: 3 } }

    assert_response :success
    assert_equal Mime[:turbo_stream], @response.media_type
    assert_includes @response.body, "turbo-stream"
  end

  test "create renders the turbo_stream fragment with 422 for invalid input" do
    @request.headers["Accept"] = Mime[:turbo_stream].to_s
    post :create, params: { slug: "test_double", inputs: { x: "" } }

    assert_response :unprocessable_entity
    assert_includes @response.body, "turbo-stream"
  end

  test "create is 404 for an unknown slug" do
    @request.headers["Accept"] = Mime[:turbo_stream].to_s
    post :create, params: { slug: "no_such_calculator", inputs: {} }
    assert_response :not_found
  end
end
