# frozen_string_literal: true

class Api::V1::Statuses::BaseController < Api::BaseController
  include Authorization

  before_action :set_status

  private

  def set_status
    @status = Status.find(params[:status_id])
    raise ActiveRecord::RecordNotFound if Mastodon::RinspaceLocalOnly.enabled? && @status.remote?
    authorize @status, :show?
  rescue ActiveRecord::RecordNotFound, Mastodon::NotPermittedError
    not_found
  end
end
