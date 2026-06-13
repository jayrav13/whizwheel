# One dynamic controller for every calculator (ARCHITECTURE.md §3–4). The slug
# resolves to a `Calculators::X` class via auto-discovery; there is no per-calculator
# code here and nothing shared is edited to add a calculator.
#
# The response is derived from the computed result, NOT from persistence succeeding —
# so `record.save` can later become a background job with no change to the contract (§1, §5).
class CalculatorsController < ApplicationController
  def create
    klass = Calculators::Base.lookup(params[:slug])
    return head(:not_found) unless klass

    calc = klass.new(calculator_params(klass))
    if calc.valid?
      record = calc.to_calculation
      record.user = Current.user   # may be nil — anonymous calculations are allowed (§7)
      record.save                  # the only persistence point; later: a job (§5)
      render json: envelope_ok(klass, calc)
    else
      render json: envelope_invalid(klass, calc), status: :unprocessable_entity
    end
  end

  private

  # The calculator's declared attributes ARE the allowlist: permit exactly those
  # keys. Unknown keys are dropped (not 500s via UnknownAttributeError), and missing
  # `inputs` degrades to {} → the calculator's own validations produce a 422.
  def calculator_params(klass) = params.permit(inputs: klass.attribute_names).fetch(:inputs, {})

  # The one JSON envelope, identical for every calculator — the backend↔frontend seam (§4).
  def envelope_ok(klass, calc)      = { ok: true,  calculator: klass.slug, inputs: calc.attributes, result: calc.result }
  def envelope_invalid(klass, calc) = { ok: false, calculator: klass.slug, errors: calc.errors.to_hash }
end
