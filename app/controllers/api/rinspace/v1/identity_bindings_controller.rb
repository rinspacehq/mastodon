# frozen_string_literal: true

class Api::Rinspace::V1::IdentityBindingsController < Api::Rinspace::V1::BaseController
  def create
    permitted = identity_params
    result = Rinspace::EnsureIdentityService.new.call(
      subject: permitted[:subject], handle: permitted[:handle], display_name: permitted[:displayName],
      avatar_url: permitted[:avatarUrl] || '', bio: permitted[:bio] || '', version: permitted[:version],
      state: permitted[:state] || 'active'
    )
    render json: { accountId: result.account.id, handle: result.account.username, version: result.version }
  rescue ArgumentError
    render json: { error: 'invalid_request' }, status: :unprocessable_content
  end

  private

  def identity_params
    params.permit(:subject, :handle, :displayName, :avatarUrl, :bio, :version, :state)
  end
end
