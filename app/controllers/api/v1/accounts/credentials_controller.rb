# frozen_string_literal: true

class Api::V1::Accounts::CredentialsController < Api::BaseController
  before_action -> { doorkeeper_authorize! :profile, :read, :'read:accounts' }, except: [:update]
  before_action -> { doorkeeper_authorize! :write, :'write:accounts' }, only: [:update]
  before_action :require_user!
  before_action :reject_rinspace_source_profile_update!, only: :update

  def show
    @account = current_account
    render json: @account, serializer: REST::CredentialAccountSerializer
  end

  def update
    @account = current_account
    UpdateAccountService.new.call(@account, account_params, raise_error: true)
    current_user.update(user_params) if user_params
    ActivityPub::UpdateDistributionWorker.perform_in(ActivityPub::UpdateDistributionWorker::DEBOUNCE_DELAY, @account.id)
    render json: @account, serializer: REST::CredentialAccountSerializer
  rescue ActiveRecord::RecordInvalid => e
    render json: ValidationErrorFormatter.new(e).as_json, status: 422
  end

  private

  def reject_rinspace_source_profile_update!
    return unless ENV['RINSPACE_IDENTITY_STRICT'] == 'true'

    source_owned = %i[display_name note avatar avatar_description header header_description fields_attributes].any? { |key| params.key?(key) }
    raise Mastodon::NotPermittedError if source_owned
  end

  def account_params
    params.permit(
      :display_name,
      :note,
      :avatar,
      :avatar_description,
      :header,
      :header_description,
      :locked,
      :bot,
      :discoverable,
      :hide_collections,
      :indexable,
      attribution_domains: [],
      fields_attributes: [:name, :value]
    )
  end

  def user_params
    return nil if params[:source].blank?

    source_params = params.require(:source)

    {
      settings_attributes: {
        default_privacy: source_params.fetch(:privacy, @account.user.setting_default_privacy),
        default_sensitive: source_params.fetch(:sensitive, @account.user.setting_default_sensitive),
        default_language: source_params.fetch(:language, @account.user.setting_default_language),
        default_quote_policy: source_params.fetch(:quote_policy, @account.user.setting_default_quote_policy),
      },
    }
  end
end
