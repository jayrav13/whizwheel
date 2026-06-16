import { Controller } from "@hotwired/stimulus"

// VAT page (spec issue #255): a solve-for-X value-added-tax calculator over three figures —
// the net price (before VAT), the VAT rate (%), and the gross price (after VAT). A required
// `mode` selects WHICH figure is the unknown; each mode is GIVEN exactly two figures and the
// form shows only those two (the field it solves for is left blank).
//
// Deliberate structural twin of the Sales Tax controller (net/VAT/gross ↔ before/tax/after) —
// same solve-for-X shape, same field-gating logic, differing only in domain labels.
//
// This controller is pure progressive enhancement (DESIGN.md §0.5). The page works with NO JS
// — the <form> posts inputs[...] over Turbo and the server validates exactly the selected
// mode's required pair and re-renders the #result fragment; the segmented control's active
// half is already painted by its peer:checked CSS before this connects. The controller only
// sharpens the form: (a) it reveals just the active mode's two GIVEN fields and disables the
// rest so the solved-for figure isn't posted, and (b) it lifts the active segmented half.
//
// Field visibility is data-driven: each figure's field block declares the modes that GIVE it
// via `data-vat-modes` (a space-separated list); the active mode shows only the blocks whose
// list contains it.
export default class extends Controller {
  static targets = ["modeInput", "field", "pill"]

  connect() {
    this.render()
  }

  // A mode radio changed → re-render field visibility + active states.
  select() {
    this.render()
  }

  render() {
    const mode = this.currentMode
    this.fieldTargets.forEach((field) => {
      const on = field.dataset.vatModes.split(" ").includes(mode)
      field.hidden = !on
      // Disable a hidden block's inputs so the solved-for figure isn't posted. The mode radios
      // themselves stay enabled — the picker must always submit the chosen mode.
      field.querySelectorAll("input").forEach((input) => {
        if (!(input.type === "radio" && input.name === "inputs[mode]")) {
          input.disabled = !on
        }
      })
    })
    this.paintPills(mode)
  }

  paintPills(mode) {
    this.pillTargets.forEach((pill) => {
      pill.classList.toggle("is-active", pill.dataset.mode === mode)
    })
  }

  get currentMode() {
    const checked = this.modeInputTargets.find((r) => r.checked)
    if (checked) return checked.value
    return this.modeInputTargets[0] && this.modeInputTargets[0].value
  }
}
