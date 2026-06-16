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

  # --- show: the #214 coming-soon fallback (direct-URL hardening) ----------

  test "show renders the coming-soon fallback (200) for a registry-active calculator with no page" do
    # NumericGuardDouble resolves to a Calculators::X class (registry-active) but has NO
    # app/views/calculators/numeric_guard_double page and no stub — exactly the backend-
    # before-frontend window. A DIRECT GET must degrade to the on-brand fallback, not 500.
    get :show, params: { slug: "numeric_guard_double" }

    assert_response :success # soft 200: the calculator exists; only its page is unbuilt.
    assert_includes @response.body, "Coming soon"
    # The fallback resolved a human name from the slug (no registry row → titleized).
    assert_includes @response.body, "Numeric Guard Double"
    # No result UI / form — there is nothing to compute yet.
    assert_includes @response.body, "being built"
  end

  test "show does NOT swallow a MissingTemplate raised from within a real page (genuine bug surfaces)" do
    # BuggyPageDouble's page (test/support/views/calculators/buggy_page_double.html.erb)
    # EXISTS and is rendered, but it renders a partial that does NOT — a genuine template
    # bug inside a shipped page. ActionView wraps a render error raised from inside a
    # template in ActionView::Template::Error (the MissingTemplate is its #cause), so it
    # bypasses the controller's narrow `rescue ActionView::MissingTemplate` entirely and
    # propagates — the page still 500s, never masked as the coming-soon fallback.
    error = assert_raises(ActionView::Template::Error) do
      get :show, params: { slug: "buggy_page_double" }
    end
    # The underlying cause is the missing PARTIAL — proving it was a real in-page bug, not
    # the calculator's own page template being absent (the only case the rescue handles).
    assert_instance_of ActionView::MissingTemplate, error.cause
    assert error.cause.partial, "the swallowed-only case is a non-partial page template"
  end

  test "show re-raises a MissingTemplate that is NOT the calculator's own page (rescue stays narrow)" do
    # The wrapping case above bypasses the bare `rescue ActionView::MissingTemplate`, so to
    # pin the rescue's OTHER guard arm — the re-raise when a bare MissingTemplate that DOES
    # reach the rescue is not the calculator's own page — we force exactly that: a bare
    # MissingTemplate whose path is a DIFFERENT, non-partial template (here a layout). This
    # is the production safety property: the rescue degrades ONLY the missing
    # `calculators/<slug>` page; any other missing top-level template surfaces as a 500.
    not_own_page = ActionView::MissingTemplate.new(
      [ "/views" ], "some_other_template", [ "layouts" ], false, []
    )
    # Make the controller's render raise that non-own-page error (the
    # `render "calculators/<slug>"` in #render_calculator_page) — minitest/mock's #stub is
    # blocked by Ruby 3.4's bundled-gems shim, so override render on this one-off controller
    # instance (a fresh @controller per test, so no restore is needed). missing_own_page?
    # returns false for this error, so the rescue re-raises it (never reaching
    # `render "calculators/unavailable"`), proving the guard's narrowness.
    @controller.define_singleton_method(:render) { |*| raise not_own_page }
    raised = assert_raises(ActionView::MissingTemplate) do
      get :show, params: { slug: "test_double" }
    end
    assert_same not_own_page, raised
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
