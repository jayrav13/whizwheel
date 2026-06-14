import { Controller } from "@hotwired/stimulus"

// BMI page (spec issue #53) — pure progressive enhancement over a form that already
// works WITHOUT JS. A unit-system toggle (US / Metric) selects which formula the server
// runs and which height affordance the page collects.
//
//   • The canonical submitted fields are always `inputs[weight]` and `inputs[height]`
//     (total inches for US, centimetres for metric) plus the checked `inputs[unit_system]`
//     radio. Without JS the user types weight and a single height value straight into those
//     fields; the US height field is labelled "Total height in inches" so the no-JS path is
//     self-explanatory, and the server computes from them.
//   • With JS, US mode hides the raw total-inches field and reveals friendlier feet + inches
//     helper inputs (which carry NO name, so are never posted); the controller sums them into
//     the canonical height field live. Metric mode keeps a single centimetres field. The
//     controller also swaps the weight unit affix (lb ↔ kg) and lifts the active segmented
//     half (.is-active mirrors the .peer:checked no-JS paint).
//
// Visibility is data-driven: each per-system block declares the systems it belongs to via
// `data-bmi-systems` (space-separated). The active system shows only its blocks and disables
// the inputs in hidden blocks so they are never submitted. Within the US block, the ft+in
// helpers (feetInches) and the raw total-inches field (totalInches) swap by JS presence so
// each path shows exactly one height affordance.
export default class extends Controller {
  static targets = [
    "systemInput", "pill", "field", "weightUnit",
    "feetInches", "totalInches", "feet", "inches", "usHeight"
  ]
  static values = { weightUnits: Object }

  connect() {
    // JS is here: reveal the ft+in helpers and hide the raw total-inches affordance,
    // then render the initial state.
    if (this.hasFeetInchesTarget) this.feetInchesTarget.hidden = false
    if (this.hasTotalInchesTarget) this.totalInchesTarget.hidden = true
    this.render()
  }

  // A unit-system radio changed → re-render visibility, the affix, active states, and the
  // canonical height from whichever inputs the new system shows.
  select() {
    this.render()
  }

  // A feet/inches helper changed → sum into the canonical US height field (inputs[height]),
  // which is what actually posts in US mode. A blank pair clears it.
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
      const on = (field.dataset.bmiSystems || "").split(/\s+/).includes(system)
      field.hidden = !on
      // Disable non-radio inputs in hidden blocks so they never post; re-enable on show.
      field.querySelectorAll("input").forEach((input) => {
        if (input.type !== "radio") input.disabled = !on
      })
    })

    // In JS mode the raw total-inches affordance stays hidden, but its input must remain
    // enabled in US mode so the summed value still posts (the loop above re-enabled it).
    if (system === "us" && this.hasTotalInchesTarget) {
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
