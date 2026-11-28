# frozen_string_literal: true

class OAuth::AuthorizationsController < Doorkeeper::AuthorizationsController
  prepend_before_action :store_current_location

  layout 'modal'

  content_security_policy do |p|
    p.form_action(false)
  end

  include Localized

  private

  def store_current_location
    mobile_return = Rinspace::MobileOAuthResume.stage(session, request.query_parameters) if request.get? && current_user.nil?
    store_location_for(:user, mobile_return || request.url)
  end

  def can_authorize_response?
    !truthy_param?('force_login') && super
  end

  def truthy_param?(key)
    ActiveModel::Type::Boolean.new.cast(params[key])
  end

  def mfa_setup_path
    super({ oauth: true })
  end
end
