# frozen_string_literal: true

class Api::Rinspace::V1::FollowsController < Api::Rinspace::V1::BaseController
  def create
    result = Rinspace::SetFollowService.new.call(
      actor_account_id: params.require(:actorAccountId), target_account_id: params.require(:targetAccountId),
      active: ActiveModel::Type::Boolean.new.cast(params[:active]), idempotency_key: params.require(:idempotencyKey)
    )
    render json: result
  rescue ArgumentError, ActionController::ParameterMissing, ActiveRecord::RecordNotFound
    render json: { error: 'invalid_request' }, status: :unprocessable_content
  end
end
