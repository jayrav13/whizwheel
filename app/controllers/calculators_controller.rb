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
  def show
    klass = Calculators::Base.lookup(params[:slug])
    return head(:not_found) unless klass

    @calculator = klass
    render "calculators/#{klass.slug}"
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
