import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js" // the self-contained chart.js/auto bundle (auto-registers controllers)

// House Affordability page (spec issue #259, DESIGN.md §4 "Charts"): the result carries one
// chart — a doughnut of the monthly HOUSING BUDGET components (P&I vs. property tax vs.
// insurance vs. HOA). This controller is pure progressive enhancement over a page that
// already works WITHOUT JS:
//
//   • The no-JS baseline is a conic-gradient ring + a text legend, both always rendered
//     server-side from the §4 envelope. With JS, this controller draws the hover-capable
//     Chart.js doughnut into the canvas target (DESIGN.md §4) and then hides the static
//     fallback. If the JS fails to load, the fallback stays — the breakdown is never gated on
//     JS, and never relies on colour alone (DESIGN.md §6).
//
// It owns no numbers and no math (CLAUDE.md; ARCHITECTURE.md §4) — it only renders values the
// backend already computed (passed in via a data attribute). connect() runs each time Turbo
// replaces the #result fragment, so a fresh calculation re-draws its chart.
export default class extends Controller {
  static targets = ["donutCanvas", "donutFallback"]
  static values = {
    donut: Array, // [{ amount, label, color }, …] — the budget-component slices, ordered
  }

  connect() {
    this.charts = []
    // The chart is enhancement, never a gate: if Chart.js misbehaves, leave the static
    // fallback in place and carry on — the budget numbers stay reachable (DESIGN.md §4).
    try { this.drawDonut() } catch (e) { console.error("house affordability donut:", e) }
  }

  disconnect() {
    // Tear down the chart so a Turbo re-render doesn't leak canvases/observers.
    this.charts.forEach((c) => c.destroy?.())
    this.charts = []
  }

  // ── Donut: the monthly housing-budget components (Chart.js, hover tooltips) ──
  drawDonut() {
    if (!this.hasDonutCanvasTarget) return

    // Reveal the canvas wrapper BEFORE constructing so Chart.js can measure a sized box (a
    // display:none parent reports 0×0). The fallback is retired only AFTER the chart is built
    // (below), so a construction failure leaves the static fallback in place.
    this.reveal(this.donutCanvasTarget)

    const slices = this.donutValue
    const css = (name) => getComputedStyle(this.element).getPropertyValue(name).trim()
    // Chart.js needs the <canvas> element itself (not its wrapper div) to acquire a 2D context
    // — passing the wrapper fails with "can't acquire context from the given item" and renders
    // nothing. The wrapper is the target (so we can size/reveal it); the canvas lives inside.
    const canvas = this.donutCanvasTarget.querySelector("canvas")
    // The slice order (largest P&I → coral → amber → quiet) and each slice's token colour are
    // decided server-side (DESIGN.md §1); we honour both — labels, amounts, and colours come
    // straight from the data attribute, the JS re-derives nothing.
    const chart = new Chart(canvas, {
      type: "doughnut",
      data: {
        labels: slices.map((s) => s.label),
        datasets: [{
          data: slices.map((s) => Number(s.amount)),
          backgroundColor: slices.map((s) => css(`--color-${s.color}`)),
          borderColor: css("--color-surface"),
          borderWidth: 3,
          hoverOffset: 4,
        }],
      },
      options: {
        // responsive:false → Chart.js draws at the canvas's own width/height attributes
        // (112×112, set in the view), independent of when the parent's layout reflows.
        // responsive:true read a not-yet-laid-out parent on CI and rendered a blank 0×0.
        responsive: false,
        maintainAspectRatio: false,
        cutout: "62%",
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: css("--color-ink"),
            titleFont: { family: css("--font-sans"), weight: "700" },
            bodyFont: { family: css("--font-sans") },
            padding: 10,
            callbacks: {
              label: (ctx) => `  $${this.money(ctx.parsed)}`,
            },
          },
        },
      },
    })
    this.charts.push(chart)
    this.retire(this.donutFallbackTarget) // chart built — hide the static fallback
  }

  // Reveal the JS chart canvas: clear its `hidden` attribute AND force display so neither the
  // attribute nor a utility class can keep it collapsed at chart-construction time (a
  // display:none parent measures 0×0).
  reveal(canvasWrap) {
    canvasWrap.hidden = false
    canvasWrap.style.display = ""
  }

  // Retire the static (no-JS) fallback once the live chart is built — unambiguous to both the
  // browser and the system test's visibility check. Called only on success, so a chart that
  // fails to build leaves its fallback visible (DESIGN.md §4 — never gate on JS).
  retire(fallback) {
    fallback.hidden = true
    fallback.style.display = "none"
  }

  // Two-decimal, thousands-delimited money for the tooltips. The backend owns the figures;
  // this only formats a number it was handed for the hover label.
  money(value) {
    return Number(value).toLocaleString(undefined, {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    })
  }
}
