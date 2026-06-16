import { Controller } from "@hotwired/stimulus"

// Average Return page (spec issue #257). The dynamic add/remove LIST UI for the period
// returns — each entry posts as `inputs[returns][]`, the variable-length list the backend
// permits via Base.array_attribute (ARCHITECTURE.md §3.2). This is pure progressive
// enhancement layered over a form that ALREADY works without JS: the page server-renders a
// few starter rows, each a plain `inputs[returns][]` field, so a no-JS visitor can fill the
// existing rows and submit (the server drops blanks and validates ≥ 1 remains). This
// controller adds the polish — an "Add return" button that clones a fresh row, a per-row
// remove button, and a live period-count chip — that turns a fixed set of fields into a
// genuinely variable-length list.
//
// Design notes (DESIGN.md §3/§4):
//   • The row template is a hidden <template> in the markup, cloned on Add — so a new row
//     carries the identical .field-input vocabulary and remove affordance, no string HTML.
//   • Remove is disabled-to-the-floor: never let the user delete the last row (an empty list
//     can't be submitted), so a single remaining row keeps its remove button hidden.
//   • A newly-added row is focused, so adding several returns in a row is keyboard-fluid.
//   • Each row is auto-numbered ("Period 1, 2, …") for orientation; renumbered on add/remove.
export default class extends Controller {
  static targets = ["list", "row", "template", "count", "removeButton", "label"]

  connect() {
    this.renumber()
  }

  // "Add return" tapped → clone the template row, append it, focus its input, renumber.
  add(event) {
    event.preventDefault()
    const fragment = this.templateTarget.content.cloneNode(true)
    this.listTarget.appendChild(fragment)
    const added = this.rowTargets[this.rowTargets.length - 1]
    const input = added.querySelector("input")
    if (input) input.focus()
    this.renumber()
  }

  // A row's remove button tapped → drop that row, then renumber. The last row can never be
  // removed (renumber hides its button), so this always leaves at least one row.
  remove(event) {
    event.preventDefault()
    const row = event.target.closest("[data-return-list-target='row']")
    if (row && this.rowTargets.length > 1) row.remove()
    this.renumber()
  }

  // Re-label rows "Period 1…n", update the live count chip, and hide the remove button when
  // only one row remains (you can't submit an empty list — DESIGN.md §6: state by more than
  // disabled styling, so the affordance simply isn't offered for the last row).
  renumber() {
    const rows = this.rowTargets
    rows.forEach((row, index) => {
      const label = row.querySelector("[data-return-list-target='label']")
      if (label) label.textContent = `Period ${index + 1}`
      const remove = row.querySelector("[data-return-list-target='removeButton']")
      if (remove) remove.hidden = rows.length === 1
    })
    if (this.hasCountTarget) {
      this.countTarget.textContent = rows.length === 1 ? "1 period" : `${rows.length} periods`
    }
  }
}
