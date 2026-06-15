module Calculators
  # calculator.net's Date Calculator (spec issue #194) — a two-mode date-math
  # calculator. The class is `Calculators::Date`, which shadows Ruby's stdlib
  # `Date` inside this namespace, so all stdlib date references below are fully
  # qualified as `::Date`.
  #
  # Modes (selected by the `mode` input):
  #
  #   1. `difference`    — the magnitude (order-independent) of the interval between
  #      `start_date` and `end_date`: an exact `total_days` count, a calendar-aware
  #      years / months / days breakdown (the Age-calculator borrowing algorithm,
  #      computed from the earlier date to the later one), and a weeks-and-remainder
  #      view (`total_weeks` = total_days // 7, `remainder_days` = total_days % 7).
  #
  #   2. `add_subtract` — `start_date` shifted by a signed offset. `operation`
  #      (`add` / `subtract`) supplies the sign; the four unsigned `years` / `months`
  #      / `weeks` / `days` magnitudes supply the amount. Years then months are
  #      applied as calendar-aware shifts with END-OF-MONTH CLAMPING (Jan 31 + 1
  #      month → Feb 28/29; Feb 29 + 1 year → Feb 28 in a non-leap year), then weeks
  #      (×7) and days are applied as exact day arithmetic (leap days included).
  #
  # Date handling (per spec, mirroring Age): both date fields are ActiveModel
  # `:date` attributes — "YYYY-MM-DD" coerces to a `::Date`, and an invalid/
  # unparseable date (e.g. "2023-02-30") coerces silently to nil. We capture the raw
  # input so a supplied-but-unparseable date is a validation error ("is not a valid
  # date"), never a 500. The four offset fields are `:integer` attributes; the
  # `Calculators::Base` numeric guard rejects non-numeric/fractional raw input at the
  # cast seam, so no `only_integer` workaround is needed (spec Notes).
  #
  # All counts are whole integers; dates are exact (no rounding, §10). `result_date`
  # is serialized as an ISO `YYYY-MM-DD` string.
  class Date < Base
    DIFFERENCE = "difference".freeze
    ADD_SUBTRACT = "add_subtract".freeze
    MODES = [ DIFFERENCE, ADD_SUBTRACT ].freeze
    OPERATIONS = %w[add subtract].freeze
    DAYS_PER_WEEK = 7

    attribute :mode, :string
    attribute :start_date, :date
    attribute :end_date, :date
    attribute :operation, :string
    attribute :years, :integer, default: 0
    attribute :months, :integer, default: 0
    attribute :weeks, :integer, default: 0
    attribute :days, :integer, default: 0

    validates :mode, presence: true, inclusion: { in: MODES, allow_blank: true }
    validates :years, :months, :weeks, :days, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

    validate :start_date_present_and_valid
    validate :end_date_present_and_valid_for_difference
    validate :operation_valid_for_add_subtract

    # Capture whether a raw value was supplied for each date, so a supplied-but-
    # unparseable date ("2023-02-30") is distinguishable from an omitted one (both
    # leave the coerced attribute nil). Mirrors the Age calculator.
    def start_date=(value)
      @start_date_supplied = value.present?
      super
    end

    def end_date=(value)
      @end_date_supplied = value.present?
      super
    end

    private

    def difference_mode? = mode == DIFFERENCE
    def add_subtract_mode? = mode == ADD_SUBTRACT

    def start_date_present_and_valid
      if @start_date_supplied
        errors.add(:start_date, :invalid_date, message: "is not a valid date") if start_date.nil?
      else
        errors.add(:start_date, :blank)
      end
    end

    # `end_date` is required (and must parse) only in `difference` mode.
    def end_date_present_and_valid_for_difference
      return unless difference_mode?

      if @end_date_supplied
        errors.add(:end_date, :invalid_date, message: "is not a valid date") if end_date.nil?
      else
        errors.add(:end_date, :blank)
      end
    end

    # `operation` is required and must be add/subtract only in `add_subtract` mode.
    def operation_valid_for_add_subtract
      return unless add_subtract_mode?

      if operation.blank?
        errors.add(:operation, :blank)
      elsif OPERATIONS.exclude?(operation)
        errors.add(:operation, :inclusion)
      end
    end

    def compute
      difference_mode? ? difference_result : add_subtract_result
    end

    # --- difference mode -----------------------------------------------------

    def difference_result
      earlier, later = [ start_date, end_date ].minmax
      total_days = (later - earlier).to_i
      years, months, days = calendar_breakdown(earlier, later)

      {
        mode: DIFFERENCE,
        total_days: total_days,
        years: years,
        months: months,
        days: days,
        total_weeks: total_days / DAYS_PER_WEEK,
        remainder_days: total_days % DAYS_PER_WEEK
      }
    end

    # The Age-calculator borrowing algorithm (leap-aware), from the earlier date to
    # the later date. days borrow the day-count of the month preceding the LATER
    # month; months borrow 12 from years.
    def calendar_breakdown(earlier, later)
      years  = later.year - earlier.year
      months = later.month - earlier.month
      days   = later.day - earlier.day

      if days.negative?
        months -= 1
        days += days_in_preceding_month(later)
      end

      if months.negative?
        years -= 1
        months += 12
      end

      [ years, months, days ]
    end

    # Days in the month immediately before the given date's month (January → the
    # prior December). Leap-aware via stdlib ::Date arithmetic.
    def days_in_preceding_month(date)
      previous = date.prev_month
      ::Date.new(previous.year, previous.month, -1).day
    end

    # --- add_subtract mode ---------------------------------------------------

    def add_subtract_result
      sign = operation == "add" ? 1 : -1
      shifted = shift_months(start_date, sign * (years * 12 + months))
      shifted += sign * (weeks * DAYS_PER_WEEK + days)

      {
        mode: ADD_SUBTRACT,
        result_date: shifted.iso8601,
        start_date: start_date.iso8601,
        operation: operation
      }
    end

    # Shift a date by a (signed) number of calendar months, clamping an overflowed
    # day to the target month's last day (Jan 31 + 1 month → Feb 28/29; Feb 29 + 12
    # months → Feb 28 in a non-leap year). Years are folded into months by the caller.
    def shift_months(date, total_months)
      return date if total_months.zero?

      base = (date.year * 12) + (date.month - 1) + total_months
      target_year = base / 12
      target_month = (base % 12) + 1
      last_day = ::Date.new(target_year, target_month, -1).day
      ::Date.new(target_year, target_month, [ date.day, last_day ].min)
    end
  end
end
