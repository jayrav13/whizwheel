import { Controller } from "@hotwired/stimulus"

// Progressive enhancement for the multi-mode Percentage page (issue #31).
//
// The page works without JS: every mode's fields are present in the form and the
// server validates only the selected mode's required inputs (the backend's
// per-mode conditional validation). This controller is polish — it switches which
// fields are visible for the selected mode and drives the increase/decrease
// toggle, so the form only ever shows the inputs the chosen mode needs.
//
// Markup contract:
//   - the root element carries data-controller="percentage"
//   - mode <input type="radio" name="inputs[mode]"> elements have data-percentage-target="mode"
//   - each conditional field group has data-percentage-field="<csv of modes it belongs to>"
//   - the direction toggle radios have data-percentage-target="direction"
//   - each direction button label has data-percentage-target="directionLabel" + data-direction
export default class extends Controller {
  static targets = ["mode", "field", "direction", "directionLabel", "modeLabel"]

  connect() {
    this.update()
  }

  update() {
    const mode = this.selectedMode
    this.fieldTargets.forEach((group) => {
      const modes = (group.dataset.percentageField || "").split(",")
      group.hidden = !modes.includes(mode)
    })
    this.modeLabelTargets.forEach((label) => {
      label.classList.toggle("is-active", label.dataset.mode === mode)
    })
    this.syncDirection()
  }

  syncDirection() {
    const selected = this.directionTargets.find((r) => r.checked)
    const value = selected ? selected.value : null
    this.directionLabelTargets.forEach((label) => {
      label.classList.toggle("is-active", label.dataset.direction === value)
    })
  }

  get selectedMode() {
    const checked = this.modeTargets.find((r) => r.checked)
    return checked ? checked.value : null
  }
}
