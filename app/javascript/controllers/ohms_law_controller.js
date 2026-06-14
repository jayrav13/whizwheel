import { Controller } from "@hotwired/stimulus"

// Ohm's Law page (spec issue #55): a wrapping pill row picks the input pair (the
// `mode` — one of the six unordered pairs of V/I/R/P), and each mode needs exactly
// two of the four inputs. This controller is pure progressive enhancement — the form
// posts over Turbo and works without JS (the server validates exactly the selected
// mode's two inputs and re-renders the result fragment). The controller only
// (a) reveals the two fields the chosen mode uses, and (b) lifts the active mode pill.
//
// Field visibility is data-driven: each per-quantity field block declares the modes
// it belongs to via `data-ohms-law-modes` (space-separated). The active mode shows
// only its blocks; inputs in hidden blocks are disabled so they are never submitted.
export default class extends Controller {
  static targets = ["modeInput", "field", "pill"]

  connect() {
    this.render()
  }

  // A mode radio changed → re-render visibility + active states.
  select() {
    this.render()
  }

  render() {
    const mode = this.currentMode
    this.fieldTargets.forEach((field) => {
      const modes = (field.dataset.ohmsLawModes || "").split(/\s+/)
      const on = modes.includes(mode)
      field.hidden = !on
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
