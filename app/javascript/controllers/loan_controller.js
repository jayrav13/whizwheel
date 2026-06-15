import { Controller } from "@hotwired/stimulus"

// Loan page (spec issue #185): a fixed-rate amortizing loan with a solve-for mode
// picker. A required `mode` selects one of three unknowns to solve for (the monthly
// payment, the loan amount, or the term), and each mode needs exactly the two of the
// three loan figures it is GIVEN — the field it solves for is left blank.
//
// This controller is pure progressive enhancement (DESIGN.md §0.5). The page works with
// NO JS — the <form> posts inputs[...] over Turbo and the server validates exactly the
// selected mode's required fields and re-renders the #result fragment, and the
// .mode-option active row is already painted by its peer:checked CSS before this connects.
// The controller only sharpens the form: (a) it reveals just the fields the active mode is
// GIVEN and disables the others so the solved-for field's value is never posted, and
// (b) it lifts the active mode-option row.
//
// Field visibility is data-driven: each field block declares the modes it belongs to via
// `data-loan-modes` (space-separated); the active mode shows only its blocks.
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
      const modes = (field.dataset.loanModes || "").split(/\s+/)
      const on = modes.includes(mode)
      field.hidden = !on
      // Disable a hidden block's inputs so the solved-for figure isn't posted. The mode
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
