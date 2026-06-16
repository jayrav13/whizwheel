import { Controller } from "@hotwired/stimulus"

// Pythagorean Theorem page (spec issue #253): a selectable option list (DESIGN.md §4 "Mode
// picker") picks WHICH SIDE is unknown (the `mode` — `hypotenuse` = given legs a + b,
// `leg` = given leg a + hypotenuse c). This controller is pure progressive enhancement —
// the form posts over Turbo and works without JS (the server validates exactly the selected
// mode's two given sides and re-renders the result fragment). The controller only (a)
// reveals the two GIVEN side fields the chosen mode needs, and (b) lifts the active option
// row (the .is-active hook the .mode-option styling reads).
//
// Field visibility is data-driven: each side-field block declares the modes it belongs to
// via `data-pythagorean-theorem-modes` (space-separated). The active mode shows only its
// blocks; inputs in hidden blocks are disabled so they are never submitted (so e.g. a stale
// `c` value can't reach the server while in `hypotenuse` mode).
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
      const modes = (field.dataset.pythagoreanTheoremModes || "").split(/\s+/)
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
