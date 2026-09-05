# frozen_string_literal: true

class Api::Rinspace::V1::BaseController < ActionController::API
  before_action :authenticate_control_plane!

  rescue_from Mastodon::NotPermittedError do
    render json: { error: 'unauthorized' }, status: :unauthorized
  end

  rescue_from ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique do
    render json: { error: 'conflict' }, status: :conflict
  end

  private

  def authenticate_control_plane!
    Rinspace::ServiceRequest.verify!(request)
  end
end
