# frozen_string_literal: true

class Rinspace::SetFollowService
  def call(actor_account_id:, target_account_id:, active:, idempotency_key:)
    actor = Account.local.find(Integer(actor_account_id))
    target = Account.local.find(Integer(target_account_id))
    raise Mastodon::NotPermittedError if actor.id == target.id || idempotency_key.to_s.blank?

    request_hash = OpenSSL::Digest::SHA256.hexdigest([actor.id, target.id, active].join(':'))
    RinspaceIntegrationOperation.transaction do
      quoted_lock = RinspaceIntegrationOperation.connection.quote("follow.set:#{idempotency_key}")
      RinspaceIntegrationOperation.connection.execute("SELECT pg_advisory_xact_lock(hashtextextended(#{quoted_lock}, 0))")
      operation = RinspaceIntegrationOperation.lock.find_by(operation_type: 'follow.set', idempotency_key:)
      if operation
        raise ActiveRecord::RecordNotUnique unless operation.request_hash == request_hash

        return operation.result
      end

      operation = RinspaceIntegrationOperation.create!(operation_type: 'follow.set', idempotency_key:, request_hash:, result: {})
      active ? FollowService.new.call(actor, target) : UnfollowService.new.call(actor, target)
      operation.update!(result: {
        active: actor.following?(target),
        requested: FollowRequest.exists?(account: actor, target_account: target),
        count: target.reload.followers_count,
        actor_account_id: actor.id,
        target_account_id: target.id,
      })
      operation.result
    end
  rescue ActiveRecord::RecordNotUnique
    raise
  end
end
