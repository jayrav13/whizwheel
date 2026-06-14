import { Controller } from "@hotwired/stimulus"

// Amortization page (spec issue #84): the result includes a long payment schedule —
// a 30-year loan is 360 rows. This controller is pure progressive enhancement over a
// page that already works without JS:
//   • No JS  → every row renders inside a scroll-capped box (the no-JS baseline).
//   • With JS → the box's scroll cap is removed and the controller paginates instead,
//               showing the first page of rows and a "Show all" button that reveals
//               the rest. Far easier to scan than a trapped scroll box.
//
// It owns no numbers and no math — it only shows/hides rows the server already rendered.
// connect() runs each time Turbo replaces the #result fragment, so a fresh calculation
// re-paginates its new schedule automatically.
export default class extends Controller {
  static targets = ["row", "toggle", "scroll", "pageSize"]

  connect() {
    // Take over from the no-JS scroll baseline: drop the height cap so revealed rows
    // aren't trapped in a scroll box once we paginate.
    if (this.hasScrollTarget) {
      this.scrollTarget.classList.remove("max-h-[28rem]", "overflow-y-auto")
    }
    this.collapse()
  }

  // Show only the first page of rows; reveal the toggle if there are more.
  collapse() {
    const page = this.pageSize
    this.rowTargets.forEach((row, i) => {
      row.hidden = i >= page
    })
    if (this.hasToggleTarget) {
      this.toggleTarget.classList.toggle("hidden", this.rowTargets.length <= page)
    }
  }

  // Reveal every row and retire the toggle.
  showAll() {
    this.rowTargets.forEach((row) => {
      row.hidden = false
    })
    if (this.hasToggleTarget) this.toggleTarget.classList.add("hidden")
  }

  get pageSize() {
    if (!this.hasPageSizeTarget) return 12
    const n = parseInt(this.pageSizeTarget.dataset.page, 10)
    return Number.isFinite(n) ? n : 12
  }
}
