# frozen_string_literal: true

class Api::V1::Accounts::BaseController < Api::BaseController
  private

  def set_account
    @account = Account.without_requested_deletion.find(params[:account_id])
    raise ActiveRecord::RecordNotFound if Mastodon::RinspaceLocalOnly.enabled? && @account.remote?
  end
end
