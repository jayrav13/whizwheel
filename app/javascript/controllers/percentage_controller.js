import { Controller } from "@hotwired/stimulus"

// Percentage page (spec issue #31): the mode pills select which percentage operation
// runs, and each mode needs a different subset of inputs. This controller is pure
// progressive enhancement — the form posts over Turbo and works without JS (the server
// validates exactly the selected mode's inputs and re-renders the result fragment). The
// controller only (a) reveals the fields the chosen mode uses, (b) lifts the active mode
// pill, and (c) lifts the chosen increase/decrease toggle half.
//
// Field visibility is data-driven: each per-mode field block declares the modes it
// belongs to via `data-percentage-modes` (space-separated). The active mode shows only
// its blocks; inputs in hidden blocks are disabled so they are never submitted.
export default class extends Controller {
  static targets = ["modeInput", "field", "pill", "directionPill"]

  connect() {
    this.render()
  }

  // A mode radio changed → re-render visibility + active states.
  select() {
    this.render()
  }

  // A direction radio changed → lift the chosen toggle half.
  selectDirection() {
    this.paintDirection()
  }

  render() {
    const mode = this.currentMode
    this.fieldTargets.forEach((field) => {
      const modes = (field.dataset.percentageModes || "").split(/\s+/)
      const on = modes.includes(mode)
      field.hidden = !on
      field.querySelectorAll("input").forEach((input) => {
        if (!(input.type === "radio" && input.name === "inputs[mode]")) {
          input.disabled = !on
        }
      })
    })
    this.paintPills(mode)
    this.paintDirection()
  }

  paintPills(mode) {
    this.pillTargets.forEach((pill) => {
      pill.classList.toggle("is-active", pill.dataset.mode === mode)
    })
  }

  paintDirection() {
    this.directionPillTargets.forEach((pill) => {
      const radio = this.element.querySelector(`#${pill.htmlFor}`)
      pill.classList.toggle("is-active", Boolean(radio && radio.checked))
    })
  }

  get currentMode() {
    const checked = this.modeInputTargets.find((r) => r.checked)
    if (checked) return checked.value
    return this.modeInputTargets[0] && this.modeInputTargets[0].value
  }
}
