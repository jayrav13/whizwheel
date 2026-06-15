import { Controller } from "@hotwired/stimulus"
import { createChart, AreaSeries } from "lightweight-charts"
import Chart from "chart.js" // the self-contained chart.js/auto bundle (auto-registers controllers)

// Compound Interest result (spec issue #188, DESIGN.md §4 "Charts"): the result carries
// two charts — a principal-vs-interest donut and a year-by-year GROWTH curve. This
// controller is pure progressive enhancement over a page that already works WITHOUT JS:
//
//   • Donut  — the no-JS baseline is a CSS conic-gradient + a text legend, rendered
//     server-side from the §4 envelope. With JS this draws the hover-capable Chart.js
//     doughnut (principal vs. total interest) into the canvas, then hides the fallback.
//
//   • Growth curve  — the no-JS baseline is an SVG area+line from the backend's
//     growth_series. With JS this draws the TradingView lightweight-charts area/line
//     (crosshair + per-point tooltip), then hides the fallback. The series x is the YEAR
//     index (0,1,2,…); we format the axis/tooltip as "Start"/"Yr N" so a bare integer
//     isn't read as a UNIX epoch.
//
// If a chart library fails to load, its static fallback stays — the breakdown is never
// gated on JS (and never colour-alone — §6). It owns no numbers and no math (CLAUDE.md;
// ARCHITECTURE.md §4) — it only renders values the backend already computed (passed via
// data attributes). connect() runs each time Turbo replaces the #result fragment, so a
// fresh calculation re-draws its charts.
export default class extends Controller {
  static targets = [
    "donutCanvas", "donutFallback",
    "curveCanvas", "curveFallback",
  ]
  static values = {
    donut: Object, // { principal, principalLabel, interest, interestLabel, principalColor, interestColor }
    curve: Array,  // [{ year, balance }, …] — the year-by-year growth samples
  }

  connect() {
    this.charts = []
    // Charts are enhancement, never a gate: if a chart library misbehaves, leave that
    // chart's static fallback in place and carry on (DESIGN.md §4 — no-JS fallback).
    try { this.drawDonut() } catch (e) { console.error("compound-interest donut:", e) }
    try { this.drawCurve() } catch (e) { console.error("compound-interest curve:", e) }
  }

  disconnect() {
    // Tear down every chart so a Turbo re-render doesn't leak canvases/observers.
    this.charts.forEach((c) => c.destroy?.())
    this.charts = []
  }

  // ── Donut: principal vs. total interest (Chart.js, hover tooltips) ─────────
  drawDonut() {
    if (!this.hasDonutCanvasTarget) return

    // Reveal the canvas wrapper BEFORE constructing so Chart.js measures a sized box
    // (a display:none parent reports 0×0). The fallback is retired only AFTER the chart
    // is built, so a construction failure leaves the static fallback in place.
    this.reveal(this.donutCanvasTarget)

    const d = this.donutValue
    const css = (name) => getComputedStyle(this.element).getPropertyValue(name).trim()
    // Chart.js needs the <canvas> element itself (not its wrapper div) to acquire a 2D
    // context — passing the wrapper renders nothing. The wrapper is the target (so we can
    // size/reveal it); the canvas lives inside it.
    const canvas = this.donutCanvasTarget.querySelector("canvas")
    // Slice order largest → smaller (and which colour each carries — green for the larger,
    // coral for the smaller, DESIGN.md §1) is decided server-side. We honour it.
    const chart = new Chart(canvas, {
      type: "doughnut",
      data: {
        labels: [d.principalLabel, d.interestLabel],
        datasets: [{
          data: [Number(d.principal), Number(d.interest)],
          backgroundColor: [css(`--color-${d.principalColor}`), css(`--color-${d.interestColor}`)],
          borderColor: css("--color-surface"),
          borderWidth: 3,
          hoverOffset: 4,
        }],
      },
      options: {
        // responsive:false → Chart.js draws at the canvas's own width/height attributes
        // (112×112, set in the view), independent of when the parent's layout reflows.
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

  // ── Growth over time: lightweight-charts area+line, crosshair + tooltip ────
  drawCurve() {
    if (!this.hasCurveCanvasTarget) return
    const css = (name) => getComputedStyle(this.element).getPropertyValue(name).trim()
    const accent = css("--color-accent")

    // Reveal the canvas wrapper before createChart() so autoSize measures a sized box.
    this.reveal(this.curveCanvasTarget)

    // The series time is the YEAR index (0,1,2,…). lightweight-charts reads a bare integer
    // `time` as a UNIX timestamp (which would render "1970"/"1" on the axis), so we format
    // both the axis ticks and the crosshair/tooltip label as the term YEAR — the honest
    // timeline label, not an epoch date. (Backend owns the numbers; this is display only.)
    const yearLabel = (year) => {
      const y = Number(year)
      return y === 0 ? "Start" : `Yr ${y}`
    }

    const chart = createChart(this.curveCanvasTarget, {
      autoSize: true,
      layout: {
        background: { color: "transparent" },
        textColor: css("--color-faint"),
        fontFamily: css("--font-sans"),
        attributionLogo: false,
      },
      grid: {
        vertLines: { visible: false },
        horzLines: { color: css("--color-rule") },
      },
      rightPriceScale: { borderVisible: false },
      timeScale: {
        borderVisible: false,
        fixLeftEdge: true,
        fixRightEdge: true,
        tickMarkFormatter: (time) => yearLabel(time),
      },
      localization: {
        timeFormatter: (time) => yearLabel(time),
      },
      crosshair: { mode: 1 },
      handleScroll: false,
      handleScale: false,
    })

    // lightweight-charts wants a sorted {time, value} series with strictly increasing
    // integer times; the year index serves as that ordinal time (formatted to the term
    // year above). The backend already emits the samples in order. A fractional final-year
    // endpoint (e.g. 2.5) is rounded to keep the time axis integer-strictly-increasing;
    // the value is unchanged (the backend's exact end-of-term balance).
    const raw = this.curveValue.map((p) => ({
      time: Math.round(Number(p.year)),
      value: Number(p.balance),
    }))
    // Drop any duplicate time a rounded fractional endpoint could collide with the prior
    // whole year, keeping the later (term-endpoint) value — lightweight-charts requires
    // strictly increasing times.
    const points = raw.filter((p, i) => i === 0 || p.time > raw[i - 1].time)

    const area = chart.addSeries(AreaSeries, {
      lineColor: accent,
      topColor: this.rgba(accent, 0.18),
      bottomColor: this.rgba(accent, 0.0),
      lineWidth: 2,
      priceLineVisible: false,
      lastValueVisible: false,
      priceFormat: { type: "custom", formatter: (v) => `$${this.money(v)}` },
    })
    area.setData(points)
    chart.timeScale().fitContent()

    this.charts.push(chart)
    this.retire(this.curveFallbackTarget) // chart built — hide the static fallback
  }

  // Reveal the JS chart canvas: clear `hidden` AND force display so neither the attribute
  // nor a utility class can keep it collapsed at construction time (0×0 measures blank).
  reveal(canvasWrap) {
    canvasWrap.hidden = false
    canvasWrap.style.display = ""
  }

  // Retire a chart's static (no-JS) fallback once its live chart is built. Called only on
  // success, so a chart that fails to build leaves its fallback visible (DESIGN.md §4).
  retire(fallback) {
    fallback.hidden = true
    fallback.style.display = "none"
  }

  // ── Small display helpers (formatting only — no math) ──────────────────────
  // Two-decimal, thousands-delimited money for the tooltips. The backend owns the figures;
  // this only formats a number it was handed for the hover label.
  money(value) {
    return Number(value).toLocaleString(undefined, {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    })
  }

  // A token hex → rgba string for the area gradient stops (lightweight-charts wants a
  // concrete colour, not a CSS var). Falls back to the hex if parsing fails.
  rgba(hex, alpha) {
    const m = hex.replace("#", "")
    if (m.length !== 6) return hex
    const r = parseInt(m.slice(0, 2), 16)
    const g = parseInt(m.slice(2, 4), 16)
    const b = parseInt(m.slice(4, 6), 16)
    return `rgba(${r}, ${g}, ${b}, ${alpha})`
  }
}
