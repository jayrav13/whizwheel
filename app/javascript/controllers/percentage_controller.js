import { Controller } from "@hotwired/stimulus"

// Percentage page (spec issue #31). A multi-mode calculator: a required `mode` selects
// one of five percentage operations, and each mode needs a different subset of inputs.
//
// This controller is pure progressive enhancement (DESIGN.md §0.5). The page works with
// NO JS — the <form> posts inputs[...] over Turbo and the server validates exactly the
// selected mode and re-renders the #result fragment, and the .mode-option / .direction-pill
// active states are already painted by their peer:checked CSS before this connects. The
// controller only sharpens the form: (a) it reveals just the active mode's field blocks
// and disables the inputs in the others so they aren't submitted, (b) it lifts the active
// mode-option row, and (c) it lifts the chosen increase/decrease half.
//
// Field visibility is data-driven: each per-mode block declares the modes it belongs to
// via `data-percentage-modes` (space-separated). The active mode shows only its blocks.
export default class extends Controller {
  static targets = ["modeInput", "field", "modeOption", "directionPill"]

  connect() {
    this.render()
  }

  // A mode radio changed → re-render field visibility + active states.
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
      // Disable inactive-block inputs so a hidden mode's value is never posted. The mode
      // radios themselves stay enabled — the picker must always submit the chosen mode.
      field.querySelectorAll("input").forEach((input) => {
        if (!(input.type === "radio" && input.name === "inputs[mode]")) {
          input.disabled = !on
        }
      })
    })
    this.paintModeOptions(mode)
    this.paintDirection()
  }

  paintModeOptions(mode) {
    this.modeOptionTargets.forEach((option) => {
      option.classList.toggle("is-active", option.dataset.mode === mode)
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
