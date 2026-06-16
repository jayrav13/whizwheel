# Per-calculator helper for the VAT calculator (spec issue #255; split per issue #107). Holds
# the field-label map (single source of truth for error phrasing, DESIGN.md §4) and the mode
# table the page reads. Auto-included into views; slug `vat` →
# Calculators::VatHelper::FIELD_LABELS in field_labels_for.
#
# Deliberate structural twin of the Sales Tax calculator (net/VAT/gross ↔ before/tax/after):
# the same solve-for-X shape over three modes, differing only in domain labels. Keep parallel.
module Calculators
  module VatHelper
    # The visible label for each VAT input — what the error phrasing reads back (DESIGN.md §4:
    # "phrase each message against the field's visible label"). `mode` is the picker itself, so
    # its label names the selector, not a field.
    FIELD_LABELS = {
      "mode"        => "Solve for",
      "net_price"   => "Net price",
      "gross_price" => "Gross price",
      "rate"        => "VAT rate"
    }.freeze

    # The three solve-for modes (DESIGN.md §4 "Mode picker"): a single-select posted as
    # inputs[mode]. Three SHORT labels (≤12 chars) ⇒ per the §4 rule the picker is the
    # SEGMENTED CONTROL (the connected horizontal track), not the selectable option list.
    # `given` is the pair of fields that mode reveals (the two figures it is given); the third
    # is what the mode solves for. Order is fixed so the picker always reads the same.
    MODES = [
      { value: "gross", label: "Gross price", helper: "From net price + VAT rate", given: %w[net_price rate] },
      { value: "net",   label: "Net price",   helper: "From gross price + VAT rate", given: %w[gross_price rate] },
      { value: "rate",  label: "VAT rate",    helper: "From net price + gross price", given: %w[net_price gross_price] }
    ].freeze

    # The three modes, for the mode picker — a method so the view reaches the table without
    # qualifying the constant (templates see the module's methods, not its constants).
    def vat_modes = MODES

    # The human name of the figure a given mode solves for — drives the hero eyebrow and the
    # one-line detail under it. `gross` → "Gross price", `net` → "Net price", `rate` → "VAT rate".
    def vat_solved_label(mode)
      MODES.find { |m| m[:value] == mode }.fetch(:label)
    end

    # A short human sentence describing the solve that was performed, shown under the hero
    # answer so it reads in context. Reads the echoed mode + the solved figures (all money
    # strings; rate is a 4dp string) off the result envelope.
    #   gross → "Net $10.00 at 10% VAT → gross $11.00."
    #   net   → "Gross $11.00 at 10% VAT → net $10.00."
    #   rate  → "Net $10.00 → gross $11.00 implies a 10% VAT rate."
    def vat_detail(calc)
      r = calc.result
      net = "$#{money_display(r[:net_price])}"
      gross = "$#{money_display(r[:gross_price])}"
      rate = "#{rate_trim(r[:rate])}%"
      case r[:mode]
      when "gross" then "#{net} at #{rate} VAT → gross #{gross}."
      when "net"   then "#{gross} at #{rate} VAT → net #{net}."
      else              "#{net} → #{gross} implies a #{rate} VAT rate."
      end
    end

    # Display a rate money/percent string trimmed of trailing-zero noise. The envelope emits
    # the rate padded to 4 dp ("10.0000", "7.2500"); for prose/headline display, drop trailing
    # zeros (and a bare trailing dot) so it reads "10%", "7.25%" — never "10.0000%". A whole
    # rate keeps no decimals. Thousands-delimited via percentage_display for the integer part.
    def rate_trim(value)
      whole, frac = value.to_s.split(".")
      frac = frac.to_s.sub(/0+\z/, "")
      delimited = percentage_display(BigDecimal(whole))
      frac.empty? ? delimited : "#{delimited}.#{frac}"
    end
  end
end
