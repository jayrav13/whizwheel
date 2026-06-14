import { Controller } from "@hotwired/stimulus"

// Tip page (spec issue #76). Pure progressive enhancement: the page is a plain
// multi-input form that posts over Turbo and works without JS (the bill / tip % /
// people fields are all directly editable and the server validates + re-renders the
// #result fragment). This controller only wires the quick-pick tip-percentage chips —
// clicking one writes its value into the percent field — and lifts the chip that matches
// the field's current value so the active rate reads at a glance.
export default class extends Controller {
  static targets = ["percent", "preset"]

  // A quick-pick chip was clicked → set the percent field, then repaint the chips.
  pick(event) {
    this.percentTarget.value = event.params.value
    this.paint()
  }

  // The percent field was typed into → repaint so a manual value de-selects the chips.
  sync() {
    this.paint()
  }

  paint() {
    const current = this.percentTarget.value.trim()
    this.presetTargets.forEach((chip) => {
      chip.classList.toggle("is-active", chip.dataset.tipValueParam === current)
    })
  }
}
