# One dynamic controller for every calculator (ARCHITECTURE.md §3–4). The slug
# resolves to a `Calculators::X` class via auto-discovery; there is no per-calculator
# code here and nothing shared is edited to add a calculator.
#
# The response is derived from the computed result, NOT from persistence succeeding —
# so `record.save` can later become a background job with no change to the contract (§1, §5).
class CalculatorsController < ApplicationController
  # GET /calculators/:slug — the calculator's page. The slug must resolve to a real
  # calculator (404 otherwise); the page view itself (calculators/<slug>) is the
  # frontend's (ARCHITECTURE.md §3, issue #31). No math runs here — just serve the page.
  #
  # A calculator becomes registry-active (its slug resolves, its catalog row is live) the
  # moment its BACKEND PR merges — which can precede its frontend page by a full PR. In
  # that backend-before-frontend window the page view does not exist yet, so the
  # `render "calculators/<slug>"` below raises ActionView::MissingTemplate. The catalog
  # gates each card's LINK on the page existing, but a DIRECT URL hit still lands here —
  # so we degrade that one missing page into the on-brand "coming soon" fallback
  # (calculators/unavailable, the frontend slice of #214) with a soft 200, instead of a
  # user-facing 500. The rescue is kept TIGHT (see #render_calculator_page) so it catches
  # ONLY the missing show template for a valid-but-pageless calculator and never masks a
  # genuine template bug — e.g. a MissingTemplate raised from a partial inside a real page
  # still surfaces.
  def show
    klass = Calculators::Base.lookup(params[:slug])
    return head(:not_found) unless klass

    @calculator = klass
    render_calculator_page(klass)
  end

  def create
    klass = Calculators::Base.lookup(params[:slug])
    return head(:not_found) unless klass

    calc = klass.new(calculator_params(klass))
    return respond_invalid(klass, calc) unless calc.valid?

    # Persistence is shared and format-agnostic: it happens once, here, BEFORE the
    # respond_to — so a Turbo submit records the Calculation exactly like JSON, and
    # the response stays derived from the computed result, not from the save (§1, §5).
    record = calc.to_calculation
    record.user = Current.user   # may be nil — anonymous calculations are allowed (§7)
    record.save                  # the only persistence point; later: a job (§5)

    respond_to do |format|
      format.turbo_stream { @calc = calc } # renders calculators/create.turbo_stream.erb (frontend, #31)
      format.json { render json: envelope_ok(klass, calc) }
    end
  end

  private

  # Render the calculator's bespoke page, degrading to the "coming soon" fallback ONLY
  # when the calculator's OWN show template is the one missing (the backend-before-
  # frontend window, #214). The rescue is deliberately narrow: it re-raises any
  # MissingTemplate that is NOT the calculator's own page template — a `partial` lookup
  # (a `<%= render "..." %>` inside a real, built page) or a different path — so a genuine
  # template bug inside a shipped page still 500s and is never silently masked. The
  # fallback is a soft 200: the calculator exists and is registry-active (so 404 would
  # mislead), its page is merely not built yet, and the catalog links here as a live page.
  def render_calculator_page(klass)
    render "calculators/#{klass.slug}"
  rescue ActionView::MissingTemplate => e
    raise e unless missing_own_page?(e, klass)

    render "calculators/unavailable"
  end

  # True only when the MissingTemplate is the calculator's own page template — the
  # non-partial top-level lookup `render "calculators/<slug>"`. ActionView splits that
  # into `path == "<slug>"` + `prefixes == ["calculators"]`, so we match exactly that:
  # the page is the calculator's slug under the calculators/ prefix, and NOT a partial.
  # Anything else — a `<%= render "…" %>` partial inside a built page (partial == true),
  # or any other template path — is a genuine bug and must re-raise, never be masked.
  def missing_own_page?(error, klass)
    !error.partial &&
      error.path == klass.slug &&
      error.prefixes.include?("calculators")
  end

  # Invalid input is 422 in both formats; only the JSON branch carries the error
  # envelope (§4) — the Turbo branch re-renders the calculator's own error fragment.
  def respond_invalid(klass, calc)
    respond_to do |format|
      format.turbo_stream { @calc = calc; render "calculators/create", status: :unprocessable_entity }
      format.json { render json: envelope_invalid(klass, calc), status: :unprocessable_entity }
    end
  end

  # The calculator's declared attributes ARE the allowlist: permit exactly those
  # keys. Unknown keys are dropped (not 500s via UnknownAttributeError), and missing
  # `inputs` degrades to {} → the calculator's own validations produce a 422.
  def calculator_params(klass) = params.permit(inputs: klass.attribute_names).fetch(:inputs, {})

  # The one JSON envelope, identical for every calculator — the backend↔frontend seam (§4).
  def envelope_ok(klass, calc)      = { ok: true,  calculator: klass.slug, inputs: calc.attributes, result: calc.result }
  def envelope_invalid(klass, calc) = { ok: false, calculator: klass.slug, errors: calc.errors.to_hash }
end
