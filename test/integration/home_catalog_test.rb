require "test_helper"

# The home-page catalog guard (issue #108).
#
# A calculator becomes reachable the moment its page template exists: CalculatorsController#show
# renders "calculators/<slug>", so every `app/views/calculators/<slug>.html.erb` is a calculator
# the app will serve a GET page for. But a served page is only *discoverable* if the home grid
# links to it — and that home card is a separate, easy-to-forget wiring step (MMR shipped without
# one, PR #102, reachable only by direct URL; caught late by the visual gate, not CI).
#
# This test closes that gap: it derives the set of page-backed calculators the same way the app
# does — from the page templates — and asserts the home page renders a `/calculators/<slug>` link
# for each. If a calculator gets a page but no home card, CI fails here instead of slipping past.
class HomeCatalogTest < ActionDispatch::IntegrationTest
  # Every calculator the app serves a GET page for: one entry per page template under
  # app/views/calculators/. We exclude partials (`_*.html.erb`) and the Turbo Stream
  # response template (create.turbo_stream.erb) — only top-level page templates name a slug,
  # and that slug is exactly what #show renders and what a home card must link to.
  PAGE_VIEWS = Rails.root.join("app/views/calculators")
  CALCULATOR_PAGE_SLUGS =
    Dir.glob(PAGE_VIEWS.join("*.html.erb"))
      .map { |path| File.basename(path, ".html.erb") }
      .reject { |slug| slug.start_with?("_") || slug.include?(".") }
      .sort
      .freeze

  test "there is at least one page-backed calculator to guard" do
    # A floor so the guard can never silently pass against an empty set (e.g. if the glob
    # broke or the view directory moved). Today there are eight built pages.
    assert_operator CALCULATOR_PAGE_SLUGS.length, :>=, 1,
      "expected to discover calculator page templates under app/views/calculators/"
  end

  test "every page-backed calculator resolves to a real Calculators:: class" do
    # Sanity: the slug a page template names must be a calculator the controller can look up,
    # so the set we guard is genuinely the set the app serves (ARCHITECTURE.md §3).
    CALCULATOR_PAGE_SLUGS.each do |slug|
      assert Calculators::Base.lookup(slug),
        "page template calculators/#{slug}.html.erb does not resolve to a Calculators:: class"
    end
  end

  test "the home page links to every page-backed calculator" do
    get root_path
    assert_response :success

    CALCULATOR_PAGE_SLUGS.each do |slug|
      assert_select "a[href=?]", "/calculators/#{slug}", { count: 1 },
        "home page is missing a catalog card linking to /calculators/#{slug} " \
        "(every calculator with a page needs a discoverable home card — issue #108)"
    end
  end
end
