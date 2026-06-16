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

  # Assert that EVERY element matching `css` renders its text WITHOUT being clipped — i.e. the
  # laid-out content is fully visible, not cut off at the box edge. Clipping (data loss) is the
  # worst stat-grid failure (DESIGN.md §4: "stats must NEVER clip"): a too-wide tabular-nums
  # value inside a `.stat-card`'s `overflow-hidden` shell is silently truncated at the right
  # edge, and a markup/text assertion can't see it (the text is in the DOM, just not painted).
  # We measure the laid-out geometry: when an element's `scrollWidth` exceeds its `clientWidth`,
  # its content overflows the box and is being clipped. The never-clip safety net (overflow-wrap
  # on the value, plus the `--wide` track) keeps scrollWidth within clientWidth; a regression
  # that drops it pushes scrollWidth past clientWidth and this assertion fails. (1px slack for
  # sub-pixel layout rounding.)
  def assert_no_value_clip(css)
    measured = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll(#{css.to_json})).map(function (el) {
        return { scrollWidth: el.scrollWidth, clientWidth: el.clientWidth, text: el.textContent.trim() };
      })
    JS
    assert_not_empty measured, "expected at least one element matching #{css.inspect} to measure for clipping"
    measured.each do |m|
      assert_operator m["scrollWidth"], :<=, m["clientWidth"] + 1,
        "expected #{css.inspect} (#{m["text"].inspect}) to render fully without clipping " \
        "(content scrollWidth #{m["scrollWidth"]}px exceeds visible clientWidth #{m["clientWidth"]}px) " \
        "— the value is being truncated at the card edge"
    end
  end

  # Sign in through the real login form (drives the browser, exercising the full stack).
  #
  # By default this BLOCKS until login is observably complete — it asserts the "Sign out"
  # button (the universal signed-in chrome, rendered for any signed-in user by the layout
  # nav) is present, using Capybara's auto-waiting. That barrier is the fix for issue #229:
  # under full-parallel `bin/rails test:system`, returning right after the click raced the
  # in-flight login POST/redirect, so a follow-up assertion (e.g. `assert_link "Admin"`,
  # then `visit "/admin/stats"`) could run before the session cookie landed and 404 the
  # admin gate. Waiting on the signed-in nav here gives every login-dependent system test a
  # reliable "logged in and landed" barrier, instead of re-implementing the wait per test.
  #
  # Pass `expect_success: false` for the failed-login flow (wrong password), where no
  # redirect happens and "Sign out" never appears — the caller asserts the alert instead.
  def sign_in_as(username, password, expect_success: true)
    visit new_session_path
    fill_in "Username", with: username
    fill_in "Password", with: password
    click_button "Sign in"
    # The login redirect to root_path has landed once the signed-in nav paints. Capybara
    # waits up to its default timeout for this selector — the deterministic post-login barrier.
    assert_selector "nav", text: "Sign out" if expect_success
  end
end
