import { Controller } from "@hotwired/stimulus"

// Date page (spec issue #195): a selectable option list (DESIGN.md §4 "Mode picker")
// chooses the calculation mode (`difference` vs `add_subtract`), and each mode uses a
// different set of fields. This controller is pure progressive enhancement — the form
// posts over Turbo and works without JS (the server validates exactly the selected mode's
// fields and re-renders the result fragment). The controller only:
//   (a) reveals the chosen mode's field block and disables the inactive block's inputs so
//       they are never submitted (both blocks carry an inputs[start_date] field — disabling
//       the hidden one keeps a single start_date posting),
//   (b) lifts the active mode-option row (the .is-active hook the .mode-option styling reads),
//   (c) paints the Add/Subtract segmented control and mirrors the chosen operation into the
//       "Amount to add/subtract" heading word so the offsets read correctly.
//
// Field visibility is data-driven: each field block declares the modes it belongs to via
// `data-date-modes` (space-separated, mirroring the Ohm's Law controller).
export default class extends Controller {
  static targets = ["modeInput", "field", "pill", "opInput", "opPill", "opWord"]

  connect() {
    this.render()
    this.renderOp()
  }

  // A mode radio changed → re-render field visibility + the active option row.
  select() {
    this.render()
  }

  // An operation radio changed → repaint the segmented halves + the heading word.
  selectOp() {
    this.renderOp()
  }

  render() {
    const mode = this.currentMode
    this.fieldTargets.forEach((field) => {
      const modes = (field.dataset.dateModes || "").split(/\s+/)
      const on = modes.includes(mode)
      field.hidden = !on
      field.querySelectorAll("input").forEach((input) => {
        // Leave the mode radios alone (they live outside these blocks anyway); disable the
        // hidden block's data inputs so only the active mode's fields are submitted.
        if (!(input.type === "radio" && input.name === "inputs[mode]")) {
          input.disabled = !on
        }
      })
    })
    this.paintPills(mode)
  }

  renderOp() {
    const op = this.currentOp
    this.opPillTargets.forEach((pill) => {
      pill.classList.toggle("is-active", pill.dataset.operation === op)
    })
    // Mirror the operation into the "Amount to add / subtract" heading word.
    this.opWordTargets.forEach((word) => {
      word.textContent = op === "subtract" ? "subtract" : "add"
    })
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

  get currentOp() {
    const checked = this.opInputTargets.find((r) => r.checked)
    if (checked) return checked.value
    return this.opInputTargets[0] && this.opInputTargets[0].value
  }
}
