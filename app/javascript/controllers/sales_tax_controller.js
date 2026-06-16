import { Controller } from "@hotwired/stimulus"

// Sales Tax page (spec issue #252): a solve-for-X calculator over three related figures — the
// before-tax price, the tax rate, and the after-tax price. Given any TWO, the server solves for
// the third. A required `mode` selects WHICH figure is the unknown; each mode is GIVEN exactly
// two of the three fields (the third is left blank and solved).
//
// This controller is pure progressive enhancement (DESIGN.md §0.5). The page works with NO JS —
// the <form> posts inputs[...] over Turbo and the server validates exactly the selected mode's
// two required fields and re-renders the #result fragment, and the segmented control's active
// state is already painted by its peer:checked CSS before this connects. The controller only
// sharpens the form: (a) it reveals just the active mode's two fields and disables the rest so
// the solved-for figure is never posted, (b) it lifts the chosen segment, and (c) it shows only
// the active mode's helper line.
//
// Field visibility is data-driven: each field block declares the modes that give it via
// `data-sales-tax-modes` (space-separated); the active mode shows only its two blocks.
export default class extends Controller {
  static targets = ["modeInput", "field", "modeSegment", "modeHelper"]

  connect() {
    this.render()
  }

  // A mode radio changed → re-render field visibility + active states + the helper line.
  select() {
    this.render()
  }

  render() {
    const mode = this.currentMode
    this.fieldTargets.forEach((field) => {
      const modes = (field.dataset.salesTaxModes || "").split(/\s+/)
      const on = modes.includes(mode)
      field.hidden = !on
      // Disable a hidden block's inputs so the unused figure isn't posted. The mode radios
      // themselves stay enabled — the picker must always submit the chosen mode.
      field.querySelectorAll("input").forEach((input) => {
        if (!(input.type === "radio" && input.name === "inputs[mode]")) {
          input.disabled = !on
        }
      })
    })
    this.paintSegments(mode)
    this.paintHelper(mode)
  }

  paintSegments(mode) {
    this.modeSegmentTargets.forEach((segment) => {
      segment.classList.toggle("is-active", segment.dataset.mode === mode)
    })
  }

  paintHelper(mode) {
    this.modeHelperTargets.forEach((helper) => {
      helper.hidden = helper.dataset.mode !== mode
    })
  }

  get currentMode() {
    const checked = this.modeInputTargets.find((r) => r.checked)
    if (checked) return checked.value
    return this.modeInputTargets[0] && this.modeInputTargets[0].value
  }
}
