import { Controller } from "@hotwired/stimulus"
import { createChart, AreaSeries } from "lightweight-charts"
import Chart from "chart.js" // the self-contained chart.js/auto bundle (auto-registers controllers)

// Amortization page (spec issue #84, DESIGN.md §4 "Charts"): the result carries two
// charts and a long payment schedule (a 30-year loan is 360 rows). This controller is
// pure progressive enhancement over a page that already works WITHOUT JS:
//
//   • Charts  — the no-JS baseline is a text legend (donut) + an SVG curve, both always
//     rendered server-side from the §4 envelope. With JS, this controller draws the
//     hover-capable charts DESIGN.md §4 now requires — TradingView lightweight-charts for
//     the "Balance over time" line/time-series (crosshair + per-point tooltip), and
//     Chart.js for the principal-vs-interest donut (hover tooltips) — into their canvas
//     targets, then hides the static fallbacks. If the JS fails to load the fallbacks
//     stay, so the breakdown is never gated on JS (and never colour-alone — §6).
//
//   • Schedule  — without JS every row renders inside a scroll-capped box (the baseline).
//     With JS the cap is dropped and the controller paginates instead: the first page of
//     rows shows and a "Show all" button reveals the rest. Far easier to scan than a
//     trapped scroll box.
//
// It owns no numbers and no math (CLAUDE.md; ARCHITECTURE.md §4) — it only renders values
// the backend already computed (passed in via data attributes) and shows/hides rows the
// server already rendered. connect() runs each time Turbo replaces the #result fragment,
// so a fresh calculation re-draws its charts and re-paginates its new schedule.
export default class extends Controller {
  static targets = [
    "row", "toggle", "scroll", "pageSize",
    "donutCanvas", "donutFallback",
    "curveCanvas", "curveFallback",
  ]
  static values = {
    donut: Object,   // { principal, principalLabel, interest, interestLabel, principalColor, interestColor }
    curve: Array,    // [{ month, balance }, …] — the balance-over-time samples
  }

  connect() {
    this.charts = []
    // Charts are enhancement, never a gate: if a chart library misbehaves, leave that
    // chart's static fallback in place and carry on — the schedule pagination must still
    // run, and the donut/curve numbers stay reachable (DESIGN.md §4 — no-JS fallback).
    try { this.drawDonut() } catch (e) { console.error("amortization donut:", e) }
    try { this.drawCurve() } catch (e) { console.error("amortization curve:", e) }
    this.setupSchedule()
  }

  disconnect() {
    // Tear down every chart so a Turbo re-render doesn't leak canvases/observers.
    this.charts.forEach((c) => c.destroy?.())
    this.charts = []
  }

  // ── Donut: principal vs. total interest (Chart.js, hover tooltips) ─────────
  drawDonut() {
    if (!this.hasDonutCanvasTarget) return

    // Reveal the canvas wrapper BEFORE constructing so Chart.js can measure a sized box
    // (a display:none parent reports 0×0). The fallback is retired only AFTER the chart
    // is built (below), so a construction failure leaves the static fallback in place.
    this.reveal(this.donutCanvasTarget)

    const d = this.donutValue
    const css = (name) => getComputedStyle(this.element).getPropertyValue(name).trim()
    // Slice order largest → smaller is already decided server-side (the colour each slice
    // carries: green for the larger, coral for the smaller — DESIGN.md §1). We honour it.
    const chart = new Chart(this.donutCanvasTarget, {
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
        responsive: true,
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

  // ── Balance over time: lightweight-charts area+line, crosshair + tooltip ───
  drawCurve() {
    if (!this.hasCurveCanvasTarget) return
    const css = (name) => getComputedStyle(this.element).getPropertyValue(name).trim()
    const accent = css("--color-accent")

    // Reveal the canvas wrapper before createChart() so autoSize measures a sized box.
    this.reveal(this.curveCanvasTarget)

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
      timeScale: { borderVisible: false, fixLeftEdge: true, fixRightEdge: true },
      crosshair: { mode: 1 },
      handleScroll: false,
      handleScale: false,
    })

    // lightweight-charts wants a sorted {time, value} series; months map to a numeric
    // (business-day-free) time via the linear scale — we use month index as the time.
    const points = this.curveValue.map((p) => ({
      time: Number(p.month),
      value: Number(p.balance),
    }))

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

  // Reveal the JS chart canvas: clear its `hidden` attribute AND force display so neither
  // the attribute nor a utility class can keep it collapsed at chart-construction time
  // (a display:none parent measures 0×0).
  reveal(canvasWrap) {
    canvasWrap.hidden = false
    canvasWrap.style.display = ""
  }

  // Retire a chart's static (no-JS) fallback once its live chart is built — unambiguous to
  // both the browser and the system test's visibility check. Called only on success, so a
  // chart that fails to build leaves its fallback visible (DESIGN.md §4 — never gate on JS).
  retire(fallback) {
    fallback.hidden = true
    fallback.style.display = "none"
  }

  // ── Schedule pagination (pure show/hide of server-rendered rows) ───────────
  setupSchedule() {
    // Take over from the no-JS scroll baseline: drop the height cap so revealed rows
    // aren't trapped in a scroll box once we paginate.
    if (this.hasScrollTarget) {
      this.scrollTarget.classList.remove("max-h-[28rem]", "overflow-y-auto")
    }
    this.collapse()
  }

  collapse() {
    const page = this.pageSize
    this.rowTargets.forEach((row, i) => {
      row.hidden = i >= page
    })
    if (this.hasToggleTarget) {
      this.toggleTarget.classList.toggle("hidden", this.rowTargets.length <= page)
    }
  }

  showAll() {
    this.rowTargets.forEach((row) => { row.hidden = false })
    if (this.hasToggleTarget) this.toggleTarget.classList.add("hidden")
  }

  get pageSize() {
    if (!this.hasPageSizeTarget) return 12
    const n = parseInt(this.pageSizeTarget.dataset.page, 10)
    return Number.isFinite(n) ? n : 12
  }

  // ── Small display helpers (formatting only — no math) ──────────────────────
  // Two-decimal, thousands-delimited money for the tooltips. The backend owns the
  // figures; this only formats a number it was handed for the hover label.
  money(value) {
    return Number(value).toLocaleString(undefined, {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    })
  }

  // A token hex → rgba string for the area gradient stops (lightweight-charts wants
  // a concrete colour, not a CSS var). Falls back to the hex if parsing fails.
  rgba(hex, alpha) {
    const m = hex.replace("#", "")
    if (m.length !== 6) return hex
    const r = parseInt(m.slice(0, 2), 16)
    const g = parseInt(m.slice(2, 4), 16)
    const b = parseInt(m.slice(4, 6), 16)
    return `rgba(${r}, ${g}, ${b}, ${alpha})`
  }
}
