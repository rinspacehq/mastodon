# frozen_string_literal: true

class OAuth::BackchannelLogoutsController < ActionController::API
  def create
    Rinspace::BackchannelLogoutService.new.call(params.require(:logout_token))
    head :no_content
  rescue ActionController::ParameterMissing, Rinspace::BackchannelLogoutService::InvalidTokenError
    render json: { error: 'invalid_logout_token' }, status: :bad_request
  rescue Rinspace::BackchannelLogoutService::UnavailableError
    response.headers['Retry-After'] = '3'
    render json: { error: 'temporarily_unavailable' }, status: :service_unavailable
  end
end
