# frozen_string_literal: true

class Auth::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_before_action :check_self_destruct!
  skip_before_action :verify_authenticity_token

  def self.provides_callback_for(provider)
    define_method provider do
      @provider = provider
      auth = request.env['omniauth.auth']
      @user = User.find_for_omniauth(auth, current_user)

      if @user.persisted?
        request.env['rinspace.managed_parent'] = managed_parent_from(auth) if provider.to_sym == :openid_connect && ENV['RINSPACE_IDENTITY_STRICT'] == 'true'
        record_login_activity
        sign_in_and_redirect @user, event: :authentication
        set_flash_message(:notice, :success, kind: label_for_provider) if is_navigational_format?
      else
        session["devise.#{provider}_data"] = request.env['omniauth.auth']
        redirect_to new_user_registration_url
      end
    rescue ActiveRecord::RecordInvalid
      flash[:alert] = I18n.t('devise.failure.omniauth_user_creation_failure') if is_navigational_format?
      redirect_to new_user_session_url
    end
  end

  Devise.omniauth_configs.each_key do |provider|
    provides_callback_for provider
  end

  def after_sign_in_path_for(resource)
    if resource.email_present?
      stored_location_for(resource) || root_path
    else
      auth_setup_path(missing_email: '1')
    end
  end

  private

  def managed_parent_from(auth)
    claims = auth.extra&.raw_info || {}
    issuer = ENV.fetch('OIDC_ISSUER', '').delete_suffix('/')
    uid = auth.uid.to_s.strip
    sid = claims['sid'].to_s.strip
    version = claims['rin_session_version'].to_i
    auth_time = Time.zone.at(Integer(claims['auth_time'], exception: true))
    valid_sid = Rinspace::ParentSessionClient::UUID_PATTERN.match?(sid)
    raise ActiveRecord::RecordInvalid unless issuer.present? && uid.present? && valid_sid && version.positive?

    { issuer:, uid:, sid:, version:, auth_time: }
  rescue ArgumentError, TypeError
    raise ActiveRecord::RecordInvalid
  end

  def record_login_activity
    @user.login_activities.create(
      success: true,
      authentication_method: :omniauth,
      provider: @provider,
      ip: request.remote_ip,
      user_agent: request.user_agent
    )
  end

  def label_for_provider
    provider_display_name || configured_provider_name
  end

  def provider_display_name
    Devise.omniauth_configs[@provider]&.strategy&.display_name.presence
  end

  def configured_provider_name
    I18n.t("auth.providers.#{@provider}", default: @provider.to_s.chomp('_oauth2').capitalize)
  end
end
