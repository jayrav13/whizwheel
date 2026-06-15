module Calculators
  # calculator.net's Age calculator (spec issue #81) — the project's first
  # date-math calculator. Given a date of birth and an end date ("age at the date
  # of", defaulting to today), it reports the age two ways:
  #
  #   1. a calendar breakdown — years / months / days — using the standard
  #      date-subtraction BORROWING convention, and
  #   2. total-unit conversions of the same interval — total months / weeks /
  #      days / hours.
  #
  # There is no `mode` input: the inputs are simply the two dates. (The spec's
  # `multi-mode` tag is about the multiple output representations, not an input
  # selector.) All outputs are whole integers; no rounding rules apply (§10).
  #
  # Date handling (authoritative, per spec):
  #   - Both fields are ActiveModel `:date` attributes; "YYYY-MM-DD" coerces to a
  #     Date. An invalid/unparseable date (e.g. "2023-02-30", "2023-13-01")
  #     coerces silently to nil — so we capture the RAW input and, when a raw
  #     value was supplied but did not coerce, surface a label-based validation
  #     error ("is not a valid date") rather than a 500.
  #   - `birth_date` must be present and on or before `end_date` (no negative ages).
  #   - `end_date` defaults to Date.current when omitted (and only when omitted —
  #     a supplied-but-invalid end_date is rejected, not silently defaulted).
  class Age < Base
    attribute :birth_date, :date
    attribute :end_date, :date

    validate :birth_date_present_and_valid
    validate :end_date_valid_if_supplied
    validate :birth_on_or_before_end

    # Capture the raw input before ActiveModel coerces it, so a supplied-but-
    # unparseable date ("2023-02-30") is distinguishable from an omitted one
    # (both leave the coerced attribute nil). Used by the validations below.
    def birth_date=(value)
      @birth_date_supplied = value.present?
      super
    end

    def end_date=(value)
      @end_date_supplied = value.present?
      super
    end

    # The end date the math runs against: the supplied date, or today when the
    # field was omitted (§ spec "defaults to today"). nil only when a value WAS
    # supplied but failed to parse — in which case validation has already failed,
    # so #compute never runs on it.
    def effective_end_date
      return end_date if end_date
      return nil if @end_date_supplied # supplied but unparseable → validation error

      ::Date.current
    end

    private

    def birth_date_present_and_valid
      if @birth_date_supplied
        errors.add(:birth_date, :invalid_date, message: "is not a valid date") if birth_date.nil?
      else
        errors.add(:birth_date, :blank)
      end
    end

    def end_date_valid_if_supplied
      return unless @end_date_supplied && end_date.nil?

      errors.add(:end_date, :invalid_date, message: "is not a valid date")
    end

    # No negative ages: birth must be on or before the (effective) end date. Only
    # runs once both dates are usable, so it never piles onto a blank/invalid error.
    def birth_on_or_before_end
      return if birth_date.nil?

      finish = effective_end_date
      return if finish.nil?

      return unless birth_date > finish

      errors.add(:birth_date, :after_end_date, message: "must be on or before the end date")
    end

    def compute
      finish = effective_end_date
      y, m, d = calendar_breakdown(birth_date, finish)
      total_days = (finish - birth_date).to_i

      {
        years: y,
        months: m,
        days: d,
        total_months: y * 12 + m,
        total_weeks: total_days / 7,
        total_days: total_days,
        total_hours: total_days * 24
      }
    end

    # The authoritative borrowing algorithm (spec). Leap-aware via Date#prev_month
    # for the day-count of the month immediately preceding the END month.
    def calendar_breakdown(birth, finish)
      years  = finish.year - birth.year
      months = finish.month - birth.month
      days   = finish.day - birth.day

      if days.negative?
        months -= 1
        days += days_in_preceding_end_month(finish)
      end

      if months.negative?
        years -= 1
        months += 12
      end

      [ years, months, days ]
    end

    # Days in the month immediately before the end month (if end is January →
    # December of the prior year). leap-aware: Date#prev_month lands in that month
    # and -1.day gives its last day, whose .day is the day-count.
    def days_in_preceding_end_month(finish)
      previous = finish.prev_month
      ::Date.new(previous.year, previous.month, 1).next_month.prev_day.day
    end
  end
end
