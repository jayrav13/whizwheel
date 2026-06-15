module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :resume_session
    helper_method :authenticated?, :current_user
  end

  private

  def authenticated? = Current.session.present?
  def current_user = Current.user

  # Admin-area gate (ARCHITECTURE.md §8). Halts with 404 — NOT 403 — unless the
  # current user is an admin, so the admin area is invisible to anonymous and
  # non-admin visitors alike (no "this exists but you can't see it" signal).
  # `head :not_found` matches CalculatorsController's unknown-slug behaviour.
  def require_admin!
    head :not_found unless current_user&.admin?
  end

  def resume_session
    Current.session ||= find_session_by_cookie
  end

  def find_session_by_cookie
    Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
  end

  def start_new_session_for(user)
    user.sessions.create!(ip_address: request.remote_ip, user_agent: request.user_agent).tap do |session|
      Current.session = session
      cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax, secure: Rails.env.production? }
    end
  end

  def terminate_session
    Current.session&.destroy
    cookies.delete(:session_id)
    Current.session = nil
  end
end
