# Per-calculator helper for the ROI (return on investment) calculator (spec issue #258;
# split per issue #107). Holds the field-label map (single source of truth for error
# phrasing, DESIGN.md §4) and the small display helpers the result partial reads. Auto-
# included into views; slug `roi` → Calculators::RoiHelper::FIELD_LABELS in field_labels_for.
#
# The backend owns every number (ARCHITECTURE.md §4) and emits money as fixed-2dp strings
# ("20000.00", "-2000.00") and percentages as fixed-4dp strings ("40.0000", "-20.0000").
# This frontend does NO math — it only delimits the whole part for readability and reads
# the sign to pick the positive/negative treatment (DESIGN.md §1/§6: gain → accent green,
# loss → coral, never hue alone — always paired with the sign and a "Gain"/"Loss" label).
module Calculators
  module RoiHelper
    # The visible label for each ROI input — what the error phrasing reads back (DESIGN.md
    # §4: "phrase each message against the field's visible label"). investment_years is the
    # optional period that unlocks the annualized figure.
    FIELD_LABELS = {
      "amount_invested"  => "Amount invested",
      "amount_returned"  => "Amount returned",
      "investment_years" => "Investment period"
    }.freeze

    # Whether the solved ROI is a gain (or break-even) vs. a loss. Reads the SIGN of the
    # envelope's `total_gain` string ("-2000.00" → loss); a leading "-" is the only negative
    # marker the backend emits. Drives the not-colour-alone pairing (DESIGN.md §6): a gain is
    # accent green + "Gain", a loss is coral + "Loss" — the label carries the meaning, the hue
    # only reinforces it. Break-even (gain == 0) reads as a (non-)gain in ink, see roi_tone.
    def roi_gain?(calc)
      !calc.result[:total_gain].to_s.start_with?("-")
    end

    # Whether the result is exactly break-even (zero gain, zero ROI). A break-even result is
    # neither a win nor a loss, so it reads in neutral ink rather than accent/coral.
    def roi_break_even?(calc)
      money_zero?(calc.result[:total_gain])
    end

    # The tone tokens for the headline ROI figure + its label, by result sign (DESIGN.md
    # §1/§6). A gain → accent green; a loss → coral (primary); break-even → neutral ink.
    # Returned as a small hash the view spreads onto the value and the eyebrow/tag so the
    # colour and the word always travel together (never colour alone).
    def roi_tone(calc)
      if roi_break_even?(calc)
        { value: "text-ink", tag: "text-faint", word: "Break-even" }
      elsif roi_gain?(calc)
        { value: "text-accent", tag: "text-accent", word: "Gain" }
      else
        { value: "text-primary", tag: "text-primary", word: "Loss" }
      end
    end

    # A money string from the envelope ("20000.00", "-2000.00"), delimited for display with a
    # leading "$" and the sign preserved ("-$2,000.00"). The backend already fixed it to 2dp;
    # the frontend only delimits the whole part — no rounding, no re-formatting (raw figures
    # stay exact). Mirrors money_display's String branch but keeps the sign outside the "$".
    def roi_money(value)
      negative, magnitude = split_sign(value.to_s)
      whole, frac = magnitude.split(".")
      "#{'-' if negative}$#{number_with_delimiter(whole)}.#{frac}"
    end

    # A percentage string from the envelope ("40.0000", "-20.0000"), delimited for display
    # with the sign preserved and a trailing context handled in the view ("%"). The backend
    # fixed it to 4dp; the frontend only delimits the whole part. So "40.0000" → "40.0000",
    # "-20.0000" → "-20.0000", "1234.5678" → "1,234.5678".
    def roi_percent(value)
      negative, magnitude = split_sign(value.to_s)
      whole, frac = magnitude.split(".")
      "#{'-' if negative}#{number_with_delimiter(whole)}.#{frac}"
    end

    private

    # Whether a fixed-decimal money/percentage string represents zero ("0.00", "0.0000",
    # "-0.00" all read as zero). Strips the sign and any decimal point, then checks the
    # remaining digits are all "0".
    def money_zero?(value)
      value.to_s.delete("-.").chars.all?("0")
    end

    # Split a signed fixed-decimal string into [negative?, magnitude]. "-2000.00" →
    # [true, "2000.00"]; "40.0000" → [false, "40.0000"]. The backend emits a leading "-" as
    # the only sign marker.
    def split_sign(string)
      if string.start_with?("-")
        [ true, string[1..] ]
      else
        [ false, string ]
      end
    end
  end
end
