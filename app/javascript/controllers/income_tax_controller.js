import { Controller } from "@hotwired/stimulus"

// Income Tax page (spec issue #260): a taxable income, computed against the pinned 2025 US
// federal single-filer brackets. Two ways to enter income — a directly-entered taxable income,
// or a gross income with deductions (the backend subtracts to find the taxable income, flooring
// at 0). A `mode` picker selects which path; each mode uses exactly the field block(s) it names.
//
// This controller is pure progressive enhancement (DESIGN.md §0.5). The page works with NO JS —
// the <form> posts inputs[...] over Turbo and the backend resolves the taxable income from
// whichever income source it receives (taxable_income wins if present), re-rendering the #result
// fragment; and the .mode-option active row is already painted by its peer:checked CSS before
// this connects. The controller only sharpens the form: (a) it reveals just the active mode's
// field block(s) and disables the others so an unused income source is never posted — so exactly
// one income source reaches the server, and (b) it lifts the active mode-option row.
//
// Field visibility is data-driven: each field block declares the single mode it serves via
// `data-income-tax-mode`; the active mode shows only its block(s).
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
      const on = field.dataset.incomeTaxMode === mode
      field.hidden = !on
      // Disable a hidden block's inputs so an unused income source isn't posted — only the
      // active mode's income reaches the server. The mode radios themselves stay enabled (the
      // picker must always submit the chosen mode).
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
