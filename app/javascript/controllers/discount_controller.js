import { Controller } from "@hotwired/stimulus"

// Discount page (spec issue #254): an original price and a discount, computing the final
// (sale) price and the amount saved. A required `mode` selects HOW the discount is expressed
// — a percent off, or a fixed dollar amount off — and each mode uses exactly the one discount
// field it names (the other is left blank).
//
// This controller is pure progressive enhancement (DESIGN.md §0.5). The page works with NO JS
// — the <form> posts inputs[...] over Turbo and the server validates exactly the selected
// mode's required field and re-renders the #result fragment, and the .mode-option active row is
// already painted by its peer:checked CSS before this connects. The controller only sharpens
// the form: (a) it reveals just the active mode's discount field and disables the other so its
// value is never posted, and (b) it lifts the active mode-option row.
//
// Field visibility is data-driven: each discount field block declares the single mode it serves
// via `data-discount-mode`; the active mode shows only its block.
export default class extends Controller {
  static targets = ["modeInput", "field", "modeOption"]

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
      const on = field.dataset.discountMode === mode
      field.hidden = !on
      // Disable a hidden block's inputs so the unused discount figure isn't posted. The mode
      // radios themselves stay enabled — the picker must always submit the chosen mode.
      field.querySelectorAll("input").forEach((input) => {
        if (!(input.type === "radio" && input.name === "inputs[mode]")) {
          input.disabled = !on
        }
      })
    })
    this.paintModeOptions(mode)
  }

  paintModeOptions(mode) {
    this.modeOptionTargets.forEach((option) => {
      option.classList.toggle("is-active", option.dataset.mode === mode)
    })
  }

  get currentMode() {
    const checked = this.modeInputTargets.find((r) => r.checked)
    if (checked) return checked.value
    return this.modeInputTargets[0] && this.modeInputTargets[0].value
  }
}
