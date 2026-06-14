import { Controller } from "@hotwired/stimulus"

// Simple Interest page (spec issue #78): the only interactive element is the Years|Months
// unit segmented control. No field depends on the chosen unit, so this controller is pure
// progressive enhancement and does NOT show/hide anything — the form posts over Turbo and
// works without JS (peer:checked already paints the active half before JS connects, and the
// server validates the checked inputs[unit] radio). The controller only lifts the active
// segmented half via the .is-active hook, mirroring the no-JS peer:checked look after a toggle.
export default class extends Controller {
  static targets = ["unitInput", "pill"]

  connect() {
    this.paintPills()
  }

  // A unit radio changed → lift the chosen half.
  select() {
    this.paintPills()
  }

  paintPills() {
    const unit = this.currentUnit
    this.pillTargets.forEach((pill) => {
      pill.classList.toggle("is-active", pill.dataset.unit === unit)
    })
  }

  get currentUnit() {
    const checked = this.unitInputTargets.find((r) => r.checked)
    if (checked) return checked.value
    return this.unitInputTargets[0] && this.unitInputTargets[0].value
  }
}
