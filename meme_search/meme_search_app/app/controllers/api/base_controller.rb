module Api
  # Base class for token-authenticated, machine-facing JSON endpoints.
  #
  # Inherits from ActionController::Base directly (not ApplicationController) so it does NOT
  # pick up `allow_browser versions: :modern`, which would otherwise reject non-browser HTTP
  # clients (e.g. the Telegram bot) with 406. CSRF is disabled because authentication is by
  # bearer token, not session cookie.
  class BaseController < ActionController::Base
    skip_forgery_protection

    before_action :authenticate_api_token!

    private

    def authenticate_api_token!
      expected = ENV["MEME_SEARCH_API_TOKEN"].to_s
      provided = bearer_token.presence || request.headers["X-Api-Token"].to_s

      if expected.blank? || !ActiveSupport::SecurityUtils.secure_compare(provided, expected)
        render json: { error: "Unauthorized" }, status: :unauthorized
      end
    end

    def bearer_token
      request.headers["Authorization"].to_s.sub(/\ABearer\s+/i, "")
    end
  end
end
