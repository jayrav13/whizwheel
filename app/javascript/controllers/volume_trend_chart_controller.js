import { Controller } from "@hotwired/stimulus"
import { createChart, HistogramSeries } from "lightweight-charts"

// Admin stats 30-day calculation-volume trend chart (#221 → #227 harvest). DESIGN.md §4
// "Charts" now requires EVERY chart — including dashboard charts — to use the house JS
// charting library; the prior hand-rolled inline-SVG bar chart is the forbidden
// anti-pattern. This is TradingView lightweight-charts in its `Histogram` series form (a
// bar/count-over-time chart) with the crosshair + per-bar tooltip the library gives us.
//
// Pure progressive enhancement (DESIGN.md §4 — no-JS fallback always retained): the same
// `daily_series` is rendered server-side as a <details> data table, so the numbers are
// never gated on JS. This controller draws the live chart into the `chart` div target and
// hides the static fallback only AFTER the chart paints; if JS never connects (or the
// library throws) the table stands in.
//
// It owns no numbers and no math (CLAUDE.md; ARCHITECTURE.md §4) — it only renders the
// `{ date, count }` series the backend computed, passed in via the `series` Stimulus value
// (the §-documented CalculationStats#daily_series shape, serialized in the view).
export default class extends Controller {
  static targets = ["chart", "fallback"]
  static values = { series: Array }

  connect() {
    this.chart = null
    // The chart is enhancement, never a gate: if the library misbehaves, leave the static
    // data-table fallback in place and carry on (DESIGN.md §4 — no-JS fallback).
    try {
      this.draw()
    } catch (e) {
      console.error("volume-trend chart:", e)
    }
  }

  disconnect() {
    // Tear down the chart so a Turbo re-render doesn't leak the canvas/observer.
    this.chart?.remove?.()
    this.chart = null
  }

  draw() {
    const data = this.seriesValue || []
    if (!this.hasChartTarget || data.length === 0) return

    const css = (name) => getComputedStyle(this.element).getPropertyValue(name).trim()
    const accent = css("--color-accent")
    const primary = css("--color-primary")

    // Reveal the chart container before createChart() so autoSize measures a sized box
    // (a hidden parent reports 0×0 and the chart paints blank).
    this.reveal(this.chartTarget)

    const chart = createChart(this.chartTarget, {
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
        // The series time is the calendar date string ("YYYY-MM-DD"); render the axis
        // ticks as a compact "Mon D" matching the no-JS fallback table.
        tickMarkFormatter: (time) => this.dateLabel(time),
      },
      localization: {
        // Crosshair/tooltip time label → the same compact date as the axis.
        timeFormatter: (time) => this.dateLabel(time),
      },
      crosshair: { mode: 1 },
      handleScroll: false,
      handleScale: false,
    })

    // The peak day is lifted to accent green (the rest coral) so the high point reads at a
    // glance and the chart isn't colour-only — the per-bar crosshair tooltip and the no-JS
    // table both carry the exact figure (DESIGN.md §1, §6).
    const max = Math.max(0, ...data.map((d) => Number(d.count)))
    const series = chart.addSeries(HistogramSeries, {
      priceLineVisible: false,
      lastValueVisible: false,
      priceFormat: { type: "volume" },
    })
    series.setData(
      data.map((d) => ({
        // lightweight-charts accepts a "YYYY-MM-DD" business-day string as `time`.
        time: String(d.date),
        value: Number(d.count),
        color: max > 0 && Number(d.count) === max ? accent : primary,
      })),
    )
    chart.timeScale().fitContent()

    this.chart = chart
    this.retire() // chart built — hide the static fallback
  }

  // Format a "YYYY-MM-DD" date string as a compact "Mon D" (e.g. "Jun 5") for the axis and
  // tooltip. Parsed as UTC so the label matches the date the backend emitted regardless of
  // the viewer's timezone (display formatting only — no math).
  dateLabel(time) {
    const [y, m, d] = String(time).split("-").map(Number)
    if (!y || !m || !d) return String(time)
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    return `${months[m - 1]} ${d}`
  }

  // Reveal the live chart container: clear `hidden` AND force display so neither the
  // attribute nor a utility class can keep it collapsed at chart-construction time.
  reveal(el) {
    el.hidden = false
    el.style.display = ""
  }

  // Retire the static (no-JS) data-table fallback once the live chart is built. Called only
  // on success, so a chart that fails to build leaves the table visible (DESIGN.md §4).
  retire() {
    if (this.hasFallbackTarget) {
      this.fallbackTarget.hidden = true
      this.fallbackTarget.style.display = "none"
    }
  }
}
