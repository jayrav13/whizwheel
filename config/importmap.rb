# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
# Charting libraries for the interactive result charts (DESIGN.md §4 "Charts"), delivered
# via importmap (no Node build) and vendored under vendor/javascript (no runtime CDN):
#   • lightweight-charts (TradingView) — the line/time-series "Balance over time" chart;
#     depends on fancy-canvas (its only external import).
#   • chart.js — the principal-vs-interest donut. Pinned to the self-contained `chart.js/auto`
#     ESM bundle (esm.sh, no sub-chunk imports — the split jspm/jsdelivr dist builds reference
#     u/-chunk files importmap doesn't download, which 404 at runtime). `/auto` pre-registers
#     every controller, so the FE doesn't call Chart.register.
pin "lightweight-charts" # @5.2.0
pin "fancy-canvas" # @2.1.0
pin "chart.js" # @4.5.1 — self-contained chart.js/auto bundle in vendor/javascript
