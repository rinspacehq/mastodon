# frozen_string_literal: true

class Rinspace::ManagedSessionActivationService < BaseService
  def initialize(parent_authorizer:)
    super()
    @parent_authorizer = parent_authorizer
  end

  def call(user:, session_id:, issuer:, uid:, sid:, version:, auth_time:, request: nil)
    grant = @parent_authorizer.create_binding!(issuer:, uid:, sid:, version:)
    binding_activated = false
    activation = SessionActivation.activate(
      user:,
      session_id:,
      user_agent: request&.user_agent.to_s,
      ip: request&.remote_ip,
      rinspace_parent_issuer: issuer,
      rinspace_parent_uid: uid,
      rinspace_parent_sid: sid,
      rinspace_parent_version: grant.fetch('issuedVersion'),
      rinspace_parent_auth_time: auth_time,
      rinspace_binding_id: grant.fetch('id')
    )
    @parent_authorizer.activate_binding!(uid:, binding_id: grant.fetch('id'), runtime_ref: activation.id, issued_version: grant.fetch('issuedVersion'))
    binding_activated = true
    activation
  rescue StandardError
    activation&.destroy!
    safely_fail_binding(uid, grant) if grant && !binding_activated
    raise
  end

  private

  def safely_fail_binding(uid, grant)
    @parent_authorizer.fail_binding!(uid:, binding_id: grant.fetch('id'))
  rescue StandardError
    nil
  end
end
