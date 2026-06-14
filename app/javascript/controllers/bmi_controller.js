import { Controller } from "@hotwired/stimulus"

// BMI page (spec issue #53): a unit-system toggle (US / Metric) selects which formula
// the server runs, and which height inputs the page collects. This controller is pure
// progressive enhancement — the form posts over Turbo and works WITHOUT JS:
//
//   • The canonical submitted fields are always `inputs[weight]` and `inputs[height]`
//     (total inches for US, cm for metric) plus the checked `inputs[unit_system]` radio.
//     Without JS the user types weight and a single height value directly into those
//     fields, and the server computes from them. The US height field is labeled
//     "Total height in inches" so the no-JS path is self-explanatory.
//   • With JS, US mode hides the raw total-inches field and reveals friendlier
//     feet + inches helper inputs (which carry NO name, so are never posted); the
//     controller sums them into the canonical height field live. Metric mode keeps a
//     single centimetres field. The controller also swaps the weight unit affix
//     (lb ↔ kg) and lifts the active unit-system pill.
//
// System visibility is data-driven: each per-system block declares the systems it
// belongs to via `data-bmi-systems` (space-separated); the active system shows only its
// blocks and disables inputs in hidden blocks so they are never submitted. Within the US
// block, the ft+in helpers (feetInches) and the raw total-inches field (totalInches) are
// swapped by JS presence so each path shows exactly one height affordance.
export default class extends Controller {
  static targets = [
    "systemInput", "pill", "field", "weightUnit",
    "feetInches", "totalInches", "feet", "inches", "usHeight"
  ]
  static values = { weightUnits: Object }

  connect() {
    // JS is present: reveal the ft+in helpers and hide the raw total-inches affordance.
    if (this.hasFeetInchesTarget) this.feetInchesTarget.hidden = false
    if (this.hasTotalInchesTarget) this.totalInchesTarget.hidden = true
    this.render()
  }

  // A unit-system radio changed → re-render visibility, affixes and active states,
  // and recompute the canonical height from whichever inputs the new system shows.
  select() {
    this.render()
  }

  // A feet/inches helper changed → recompute total inches into the canonical US height
  // field (inputs[height]); that field is what actually posts in US mode.
  syncHeight() {
    if (this.currentSystem !== "us") return
    if (!this.hasFeetTarget || !this.hasInchesTarget || !this.hasUsHeightTarget) return
    const feet = parseFloat(this.feetTarget.value)
    const inches = parseFloat(this.inchesTarget.value)
    if (Number.isNaN(feet) && Number.isNaN(inches)) {
      this.usHeightTarget.value = ""
      return
    }
    const total = (Number.isNaN(feet) ? 0 : feet) * 12 + (Number.isNaN(inches) ? 0 : inches)
    this.usHeightTarget.value = String(total)
  }

  render() {
    const system = this.currentSystem
    this.fieldTargets.forEach((field) => {
      const systems = (field.dataset.bmiSystems || "").split(/\s+/)
      const on = systems.includes(system)
      field.hidden = !on
      field.querySelectorAll("input").forEach((input) => {
        if (input.type !== "radio") input.disabled = !on
      })
    })
    // In JS mode the raw total-inches affordance stays hidden, but its input must remain
    // enabled in US mode so the summed value still posts (render() re-enabled it above).
    if (this.currentSystem === "us" && this.hasTotalInchesTarget) {
      this.totalInchesTarget.hidden = true
    }
    this.paintPills(system)
    this.paintWeightUnit(system)
    this.syncHeight()
  }

  paintPills(system) {
    this.pillTargets.forEach((pill) => {
      pill.classList.toggle("is-active", pill.dataset.system === system)
    })
  }

  paintWeightUnit(system) {
    if (!this.hasWeightUnitTarget) return
    this.weightUnitTarget.textContent = this.weightUnitsValue[system] || ""
  }

  get currentSystem() {
    const checked = this.systemInputTargets.find((r) => r.checked)
    if (checked) return checked.value
    return this.systemInputTargets[0] && this.systemInputTargets[0].value
  }
}
