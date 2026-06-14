require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1280, 900 ]

  # Capture a FULL-PAGE screenshot (beyond the viewport) to tmp/screenshots/<name>.png.
  #
  # Selenium's default screenshot is viewport-only; we grow the window to the full
  # document height first so tall pages (e.g. calculators with schedules) are captured
  # whole. Returns the path so callers/CI can collect it.
  def screenshot_full_page(name)
    path = Rails.root.join("tmp", "screenshots", "#{name}.png")
    FileUtils.mkdir_p(path.dirname)

    # Hide Turbo's transient navigation progress bar so it never streaks the capture.
    page.execute_script(
      "var s=document.createElement('style');" \
      "s.textContent='.turbo-progress-bar{display:none!important}';" \
      "document.head.appendChild(s);"
    )

    width  = [ 1280, page.evaluate_script("document.documentElement.scrollWidth").to_i ].max
    height = [ 900, page.evaluate_script("document.documentElement.scrollHeight").to_i ].max
    page.driver.browser.manage.window.resize_to(width, height)

    page.save_screenshot(path.to_s)
    path
  end

  # Assert that EVERY element matching `css` renders its text on a SINGLE line — i.e. no big
  # value wrapped mid-number. A tabular-nums figure (998,001,000 W / $1,000,000.00) wrapping
  # inside a too-narrow stat-grid track is the exact regression the wide-track modifier guards
  # (DESIGN.md §4 "Stat grid"); a blank/markup assertion can't see a wrap, so we measure the
  # laid-out geometry: a one-line element's rendered height is ~one computed line-height, a
  # two-line wrap is ~double. We allow up to 1.6× line-height as the single-line ceiling
  # (slack for line-box rounding) — a real mid-number wrap clears it comfortably.
  def assert_no_mid_value_wrap(css)
    measured = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll(#{css.to_json})).map(function (el) {
        var cs = getComputedStyle(el);
        var lh = parseFloat(cs.lineHeight);
        if (isNaN(lh)) { lh = parseFloat(cs.fontSize) * 1.2; }
        return { height: el.getBoundingClientRect().height, lineHeight: lh, text: el.textContent.trim() };
      })
    JS
    assert_not_empty measured, "expected at least one element matching #{css.inspect} to measure for wrap"
    measured.each do |m|
      assert_operator m["height"], :<=, m["lineHeight"] * 1.6,
        "expected #{css.inspect} (#{m["text"].inspect}) to render on a single line " \
        "(height #{m["height"]}px vs line-height #{m["lineHeight"]}px) — it wrapped mid-value"
    end
  end

  # Sign in through the real login form (drives the browser, exercising the full stack).
  def sign_in_as(username, password)
    visit new_session_path
    fill_in "Username", with: username
    fill_in "Password", with: password
    click_button "Sign in"
  end
end
