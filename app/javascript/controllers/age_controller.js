import { Controller } from "@hotwired/stimulus"

// Age page (spec issue #82). Pure progressive enhancement: the page is a plain
// two-date form that posts over Turbo and works WITHOUT JS — the server defaults the
// optional end date to today when it is left blank and validates both dates. This
// controller only wires the "Today" quick-fill button on the OPTIONAL "Age at the date
// of" (end) date (DESIGN.md §4 "Date field with Today quick-fill"): tapping it fills the
// current date into that field. It NEVER auto-prefills — blank stays blank until the user
// taps, so the today default is visible and chosen, not hidden. The required date of
// birth carries no quick-fill (DESIGN.md §4 — never auto-default a primary date).
export default class extends Controller {
  static targets = ["endDate"]

  // The "Today" button was tapped → fill the end-date field with today's date in the
  // ISO YYYY-MM-DD value a native <input type="date"> expects, built from local-time
  // parts so it matches the user's calendar day (not a UTC roll-over).
  today() {
    const now = new Date()
    const yyyy = now.getFullYear()
    const mm = String(now.getMonth() + 1).padStart(2, "0")
    const dd = String(now.getDate()).padStart(2, "0")
    this.endDateTarget.value = `${yyyy}-${mm}-${dd}`
  }
}
