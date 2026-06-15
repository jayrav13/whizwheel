module Admin
  # Base for every admin-area controller. Gates the whole namespace behind the
  # ADMIN role (ARCHITECTURE.md §8) — non-admins and anonymous visitors get a
  # 404 (see Authentication#require_admin!), so the admin area is invisible.
  class BaseController < ApplicationController
    before_action :require_admin!
  end
end
