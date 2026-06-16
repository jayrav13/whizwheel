import { Controller } from "@hotwired/stimulus"

// ROI page (spec issue #258): amount invested + amount returned → total gain and ROI %, plus
// an optional period for the annualized figure. This controller is PURE progressive enhancement
// (DESIGN.md §0.5). The page works with NO JS — the <form> posts inputs[...] over Turbo, the
// server computes every authoritative number and re-renders the #result fragment.
//
// All it does is preview the *direction* of the result as the user types: a small chip beside
// the inputs that reads "Gain" / "Loss" / "Break-even" and tints accent-green / coral / faint,
// mirroring the server result's sign treatment (DESIGN.md §1/§6 — colour paired with the word,
// never colour alone). This is sign-only sugar (a sign of returned − invested), NOT the ROI
// math — the real answer still comes from the server. The chip is hidden until both money
// fields hold a value, and never replaces the result panel.
export default class extends Controller {
  static targets = ["invested", "returned", "preview"]

  connect() {
    this.preview()
  }

  preview() {
    if (!this.hasPreviewTarget) return

    const invested = this.number(this.investedTarget)
    const returned = this.number(this.returnedTarget)

    // Need both money fields, and a positive investment, to say anything meaningful.
    if (invested === null || returned === null || invested <= 0) {
      this.previewTarget.hidden = true
      return
    }

    const gain = returned - invested
    const { word, klass } = this.tone(gain)
    this.previewTarget.hidden = false
    this.previewTarget.textContent = word
    this.previewTarget.className = `${this.baseClass} ${klass}`
  }

  tone(gain) {
    if (gain === 0) return { word: "Break-even", klass: "text-faint" }
    if (gain > 0) return { word: "Gain", klass: "text-accent" }
    return { word: "Loss", klass: "text-primary" }
  }

  // Parse a field's value to a finite number, or null when blank/non-numeric.
  number(field) {
    if (!field) return null
    const raw = field.value.trim()
    if (raw === "") return null
    const value = Number(raw)
    return Number.isFinite(value) ? value : null
  }

  get baseClass() {
    return "ml-auto rounded-full bg-current/10 px-2.5 py-0.5 text-[11px] font-bold uppercase tracking-[0.08em]"
  }
}
