# frozen_string_literal: true

class Api::Rinspace::Internal::CredentialsController < ActionController::API
  before_action :authenticate_adapter!

  def index
    user, = owner
    tokens = Doorkeeper::AccessToken.where(resource_owner_id: user.id).where.not(rinspace_credential_ref: nil).order(created_at: :desc).limit(100)
    render json: { credentials: tokens.map { |token| metadata(token) } }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'credential owner was not found' }, status: :not_found
  end

  def destroy
    user, = owner
    token = Doorkeeper::AccessToken.find_by!(resource_owner_id: user.id, rinspace_credential_ref: params[:ref])
    token.revoke
    render json: { operationId: "mastodon:#{token.rinspace_credential_ref}", state: 'complete' }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'credential was not found' }, status: :not_found
  end

  def revoke_all
    user, uid = owner
    Doorkeeper::AccessToken.where(resource_owner_id: user.id).where.not(rinspace_credential_ref: nil).find_each(&:revoke)
    render json: { operationId: "mastodon:all:#{uid}", state: 'complete' }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'credential owner was not found' }, status: :not_found
  end

  private

  def authenticate_adapter!
    expected = ENV.fetch('RINSPACE_CREDENTIAL_ADAPTER_TOKEN', '')
    actual = request.authorization.to_s.delete_prefix('Bearer ')
    head :forbidden unless expected.bytesize >= 32 && actual.bytesize == expected.bytesize && ActiveSupport::SecurityUtils.secure_compare(actual, expected)
  end

  def owner
    binding = RinspaceIdentityBinding.find_by!(subject: params[:uid], state: 'verified')
    [binding.account.user, binding.subject]
  end

  def metadata(token)
    {
      ref: token.rinspace_credential_ref,
      kind: 'oauth',
      label: token.application&.name.presence || 'OAuth application',
      scopes: token.scopes.to_a,
      createdAt: token.created_at,
      lastUsedAt: token.last_used_at,
      state: token.revoked? ? 'revoked' : 'active'
    }
  end
end
