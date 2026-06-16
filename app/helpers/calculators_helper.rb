# Shared, calculator-agnostic display formatting + the convention-based resolvers that
# make the frontend discover calculators the way the backend does (issue #107): a new
# calculator drops in its own result partial (calculators/results/<slug>) and its own
# per-calculator helper module (Calculators::<Slug>Helper, holding FIELD_LABELS + its
# display methods) and edits NO shared file. This module keeps only what every calculator
# shares — the formatters and the error-phrasing/dispatch resolvers.
#
# Ruby helpers are coverage-counted (ARCHITECTURE.md §11), so every branch here is
# exercised by a test.
module CalculatorsHelper
  # ── Shared formatters (used across multiple calculators' result partials) ──────────

  # Format a BigDecimal for display (ARCHITECTURE.md §10 — round only for display):
  # round to 6dp, trim trailing zeros, and delimit thousands. Keeps the figure exact
  # for the reference values (all terminate well within 6dp) while staying readable.
  def decimal_display(value)
    rounded = value.round(6)
    whole = rounded.frac.zero?
    number = whole ? rounded.to_i.to_s : rounded.to_s("F").sub(/0+\z/, "")
    number_with_delimiter(number)
  end
  alias_method :percentage_display, :decimal_display

  # A whole-integer count for display (e.g. the Age outputs — ARCHITECTURE.md §10, no
  # rounding) with thousands delimiters so large spans (12,418 days) stay readable and
  # align under tabular-nums.
  def integer_display(value)
    number_with_delimiter(value.to_i)
  end

  # Money for display (ARCHITECTURE.md §10 — round only for display): a fixed two decimal
  # places, half-up, thousands-delimited — so money always reads with cents ("150.00",
  # "1,150.00"). Accepts either a numeric/BigDecimal (Simple Interest passes raw values,
  # which this rounds half-up to 2dp) OR an already-rounded 2dp String from the envelope
  # (Amortization owns its rounding and emits "215838.45"/"0.00" — the FE does no math,
  # only delimits the whole part and keeps the supplied cents).
  def money_display(value)
    if value.is_a?(String)
      whole, frac = value.split(".")
      "#{number_with_delimiter(whole)}.#{frac}"
    else
      rounded = value.round(2, BigDecimal::ROUND_HALF_UP)
      number_with_delimiter(format("%.2f", rounded))
    end
  end

  # ── Coming-soon fallback (issue #214) ─────────────────────────────────────────────

  # A human display name for a calculator that has no page yet — used by the generic
  # "coming soon" fallback (calculators/unavailable.html.erb), rendered during the
  # backend-before-frontend merge window. Prefers the registry row's curated `name`
  # (resolved by slug), and falls back to a titleized slug when no registry row exists
  # (e.g. a calculator class on `main` before its INVENTORY row is ingested). Accepts the
  # `Calculators::X` class the controller looked up (it responds to `.slug`), or a raw slug.
  def calculator_display_name(calculator_or_slug)
    slug = calculator_or_slug.respond_to?(:slug) ? calculator_or_slug.slug : calculator_or_slug.to_s
    registered = Calculator.find_by(slug: slug)
    registered&.name.presence || slug.titleize
  end

  # ── Convention-based dispatch + label resolution (issue #107) ─────────────────────

  # The result partial for a calculator instance, resolved by slug (the no-central-
  # registration convention, ARCHITECTURE.md §3): the per-slug partial
  # `calculators/results/<slug>` when it exists, otherwise the generic key/value render.
  # Adding a calculator drops in `calculators/results/<slug>.html.erb` and edits nothing
  # shared.
  def calculator_result_partial(calc)
    slug = calc.class.slug
    partial = "calculators/results/#{slug}"
    lookup_context.exists?(partial, [], true) ? partial : "calculators/results/generic"
  end

  # The label map for a calculator instance, resolved dynamically (no hand-edited `case`):
  # the calculator's per-calculator helper module (Calculators::<Slug>Helper) supplies its
  # FIELD_LABELS. Anything without one (an unmapped calculator, or a non-calculator
  # ActiveModel object) gets {} — error phrasing then falls back to a humanized attribute.
  def field_labels_for(calc)
    mod = calculator_helper_module(calc)
    mod&.const_defined?(:FIELD_LABELS) ? mod.const_get(:FIELD_LABELS) : {}
  end

  # Turn an ActiveModel errors object into label-led sentences (DESIGN.md §4). A
  # field error reads "<visible label> <message>"; a whole-record (:base) error is a
  # full sentence with no label prefix. The label comes from what the page rendered.
  def calculator_error_messages(calc)
    labels = field_labels_for(calc)
    calc.errors.map do |error|
      attribute = error.attribute.to_s
      if attribute == "base"
        error.message
      else
        label = labels[attribute] || attribute.humanize
        "#{label} #{error.message}"
      end
    end
  end

  private

  # The per-calculator helper module for a calc, or nil. Resolves Calculators::<Slug>Helper
  # from the calc's slug; guards a non-calculator object (no `.slug`) and an unbuilt module.
  def calculator_helper_module(calc)
    klass = calc.class
    return nil unless klass.respond_to?(:slug)

    "Calculators::#{klass.slug.camelize}Helper".safe_constantize
  end
end
