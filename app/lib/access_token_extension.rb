# frozen_string_literal: true

module AccessTokenExtension
  extend ActiveSupport::Concern

  included do
    include Redisable

    has_many :web_push_subscriptions, class_name: 'Web::PushSubscription', inverse_of: :access_token

    after_commit :push_to_streaming_api
	before_validation :assign_rinspace_personal_credential, on: :create

    scope :expired, -> { where.not(expires_in: nil).where('created_at + MAKE_INTERVAL(secs => expires_in) < NOW()') }
    scope :not_revoked, -> { where(revoked_at: nil) }
    scope :revoked, -> { where.not(revoked_at: nil).where(revoked_at: ...Time.now.utc) }
  end

  def revoke(clock = Time)
    update(revoked_at: clock.now.utc)
  end

  def update_last_used(request, clock = Time)
    update(last_used_at: clock.now.utc, last_used_ip: request.remote_ip)
  end

  def rinspace_managed?
    rinspace_parent_uid.present? && rinspace_parent_sid.present?
  end

  def rinspace_personal?
	rinspace_credential_ref.present? && rinspace_credential_epoch.to_i.positive?
  end

  private

  def assign_rinspace_personal_credential
	return unless ENV['RINSPACE_IDENTITY_STRICT'] == 'true' && resource_owner_id.present? && !rinspace_managed?
	return if application&.superapp?

	user = User.find(resource_owner_id)
	uid = RinspaceIdentityBinding.find_by!(account_id: user.account_id, state: 'verified').subject
	status = Rinspace::ParentSessionClient.new.account_status!(uid:)
	self.rinspace_credential_ref ||= SecureRandom.uuid
	self.rinspace_credential_epoch = status.fetch('credentialEpoch').to_i
  rescue Rinspace::ParentSessionClient::InactiveError, Rinspace::ParentSessionClient::UnavailableError, ActiveRecord::RecordNotFound, KeyError
	errors.add(:base, 'Rinspace personal credential authorization is unavailable')
	throw :abort
  end

  public

  def push_to_streaming_api
    redis.publish("timeline:access_token:#{id}", { event: :kill }.to_json) if revoked? || destroyed?
  end
end
