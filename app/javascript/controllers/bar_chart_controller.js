import { Controller } from "@hotwired/stimulus"

// Dependency-free inline-SVG bar chart (admin stats #221). NO charting library —
// the admin trend chart is built from a plain Stimulus value (importmap / no-Node
// constraint), keeping the bundle self-contained.
//
// Progressive enhancement: the data is ALSO rendered server-side as a no-JS data
// table (DESIGN.md §4 "Charts" — the underlying numbers are always reachable without
// JS). This controller draws the same series as a responsive SVG bar chart inside the
// `svg` target; if JS never connects, the table stands in for it.
//
// Data contract: `data-bar-chart-series-value` is a JSON array of `{ date, count }`
// (the §-documented `CalculationStats#daily_series` shape, serialized in the view).
// The bars are coral (`primary`); the tallest bar(s) are lifted to accent green so the
// peak reads at a glance and the chart isn't colour-only (DESIGN.md §3, §6: each bar
// also carries an accessible <title> tooltip with its date + count).
export default class extends Controller {
  static targets = ["svg"]
  static values = { series: Array }

  connect() {
    this.render()
  }

  render() {
    const data = this.seriesValue || []
    if (!this.hasSvgTarget || data.length === 0) return

    // A fixed viewBox the SVG scales to its container width (preserveAspectRatio=none
    // on the bars' coordinate space via percentage widths). We use a 0..100 x 0..100
    // user space and let the SVG element stretch responsively.
    const svg = this.svgTarget
    const W = 1000
    const H = 240
    svg.setAttribute("viewBox", `0 0 ${W} ${H}`)
    svg.setAttribute("preserveAspectRatio", "none")
    svg.setAttribute("role", "img")
    svg.setAttribute("aria-label", "Daily calculation volume over the last 30 days")

    const max = Math.max(1, ...data.map((d) => d.count))
    const n = data.length
    const gap = 4 // user-space gap between bars
    const slot = W / n
    const barW = Math.max(1, slot - gap)

    const ns = "http://www.w3.org/2000/svg"
    // Clear any prior render (idempotent reconnects).
    while (svg.firstChild) svg.removeChild(svg.firstChild)

    data.forEach((d, i) => {
      const h = (d.count / max) * (H - 4)
      const x = i * slot + gap / 2
      const y = H - h

      const rect = document.createElementNS(ns, "rect")
      rect.setAttribute("x", x)
      rect.setAttribute("y", y)
      rect.setAttribute("width", barW)
      rect.setAttribute("height", Math.max(h, d.count > 0 ? 2 : 0))
      rect.setAttribute("rx", 2)
      // Peak day(s) → accent green; the rest coral. Colour is reinforced by the title.
      rect.setAttribute("class", d.count === max && max > 0 ? "fill-accent" : "fill-primary")

      const title = document.createElementNS(ns, "title")
      title.textContent = `${d.date}: ${d.count}`
      rect.appendChild(title)

      svg.appendChild(rect)
    })
  }
}
