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

  # Sign in through the real login form (drives the browser, exercising the full stack).
  def sign_in_as(username, password)
    visit new_session_path
    fill_in "Username", with: username
    fill_in "Password", with: password
    click_button "Sign in"
  end
end
