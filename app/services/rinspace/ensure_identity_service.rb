# frozen_string_literal: true

class Rinspace::EnsureIdentityService
  Result = Data.define(:account, :version)

  def call(subject:, handle:, display_name:, avatar_url:, bio:, version:, state: 'active')
    @subject = subject.to_s.strip
    @handle = handle.to_s.strip.downcase
    @display_name = display_name.to_s.strip
    @avatar_url = avatar_url.to_s.strip
    @bio = bio.to_s.strip
    @version = Integer(version)
    @state = state.to_s.strip
    @recommendation_resync_required = false
    validate!

    binding = nil
    RinspaceIdentityBinding.transaction do
      binding = RinspaceIdentityBinding.lock.find_by(subject: @subject)
      binding ||= create_binding!
      raise ActiveRecord::RecordInvalid, binding unless binding.account.local?

      return Result.new(account: binding.account, version: binding.profile_version) if @version < binding.profile_version
      if @version == binding.profile_version && (binding.current_handle != @handle || binding.state != desired_binding_state)
        raise ActiveRecord::RecordInvalid, binding
      end
      raise ActiveRecord::RecordInvalid, binding if binding.state == 'deleted' && @state != 'deleted'

      apply_profile!(binding)
      apply_state!(binding)
    end

    resync_recommendation_candidates!(binding.account) if @recommendation_resync_required

    Result.new(account: binding.account.reload, version: binding.profile_version)
  end

  private

  def validate!
    raise ArgumentError, 'invalid subject' if @subject.blank? || @subject.length > 255
    raise ArgumentError, 'invalid handle' unless Account::USERNAME_ONLY_RE.match?(@handle) && @handle.length <= 30
    raise ArgumentError, 'invalid version' if @version.negative?
    raise ArgumentError, 'invalid state' unless %w[active disabled deleted].include?(@state)
    return if @avatar_url.blank? || Mastodon::RinspaceLocalOnly.allowed_profile_media_url?(@avatar_url)

    raise ArgumentError, 'avatar URL is outside the local trust boundary'
  end

  def create_binding!
    raise ActiveRecord::RecordNotUnique if Account.local.exists?(username: @handle)

    user = User.new(
      email: "#{OpenSSL::Digest::SHA256.hexdigest(@subject).first(32)}@users.rinspace.local",
      agreement: true,
      external: true,
      account_attributes: { username: @handle, display_name: @display_name }
    )
    user.mark_email_as_confirmed!
    user.save!
    Identity.create!(provider: 'openid_connect', uid: @subject, user:)
    RinspaceIdentityBinding.create!(subject: @subject, account: user.account, current_handle: @handle, profile_version: @version, state: desired_binding_state)
  end

  def apply_profile!(binding)
    account = binding.account
    if account.username != @handle
      raise ActiveRecord::RecordNotUnique if Account.local.where.not(id: account.id).exists?(username: @handle)

      account.username = @handle
    end
    account.display_name = @display_name
    account.note = @bio
    account.avatar_remote_url = @avatar_url if @avatar_url.present?
    if account.discoverable.nil?
      account.discoverable = true
      @recommendation_resync_required = true
    end
    account.save!
    binding.update!(current_handle: @handle, profile_version: @version)
  end

  def apply_state!(binding)
    user = binding.account.user
    case @state
    when 'active'
      user.enable! if user.disabled?
      binding.update!(state: 'verified')
    when 'disabled'
      user.disable! unless user.disabled?
      binding.update!(state: 'disabled')
    when 'deleted'
      user.disable! unless user.disabled?
      binding.update!(state: 'deleted')
    end
  end

  def desired_binding_state
    @state == 'active' ? 'verified' : @state
  end

  def resync_recommendation_candidates!(account)
    return unless Rails.configuration.x.mastodon.rinspace_recommendations_enabled

    Status.kept.local.where(account_id: account.id).find_each do |status|
      Rinspace::RecommendationSyncWorker.perform_async(status.id)
    end
  end
end
